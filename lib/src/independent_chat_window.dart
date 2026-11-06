import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_window.dart';

/// OS 级独立聊天窗口：纯 View，不持有任何 IM SDK 实例。
///
/// 历史消息、发送、端到端加解密、已读全部通过跨窗口 MethodChannel 交给
/// 主窗口的 ChatWindowHost；新消息/撤回由主窗口推送过来。子窗口因此不会
/// 注册第二个原生回调端口，也不会重复 init/login SDK。
class IndependentChatWindow extends StatefulWidget {
  final int windowId;
  final ChatWindowConversation conversation;

  const IndependentChatWindow({
    Key? key,
    required this.windowId,
    required this.conversation,
  }) : super(key: key);

  @override
  State<IndependentChatWindow> createState() => _IndependentChatWindowState();
}

class _IndependentChatWindowState extends State<IndependentChatWindow> {
  late final WindowController _controller =
      WindowController.fromWindowId(widget.windowId);

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatWindowMessage> _messages = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _sending = false;
  bool _closing = false;
  String? _error;

  String get _conversationID => widget.conversation.conversationID;
  String get _title =>
      widget.conversation.showName ??
      widget.conversation.userID ??
      _conversationID;
  String? get _avatarUrl => widget.conversation.faceUrl;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_loading &&
          _messages.isNotEmpty &&
          _scroll.position.pixels <= 8) {
        _loadMore();
      }
    });
    _init();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      switch (call.method) {
        case 'chat.focus':
          await _controller.show();
          return true;
        case 'chat.logout':
          await _close();
          return true;
        case 'chat.newMessage':
          _onNewMessage(call.arguments);
          return true;
        case 'chat.revoked':
          _onRevoked(call.arguments);
          return true;
      }
      return null;
    });
    await _loadInitial();
  }

  /// 所有请求都打到主窗口（windowId=0）；超时后给出明确错误而不是白屏。
  Future<Map<String, dynamic>> _request(
      String method, Map<String, dynamic> args) async {
    final raw = await DesktopMultiWindow.invokeMethod(0, method, args)
        .timeout(const Duration(seconds: 12));
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> _loadInitial() async {
    try {
      final hello = await _request('chat.whoAmI', const {});
      if (hello['ok'] != true) {
        throw TIM_t("主窗口聊天服务未就绪");
      }
      final res = await _request('chat.getMessages', {
        'conversationID': _conversationID,
        'count': 30,
      });
      if (res['ok'] != true) {
        throw (res['error'] as String?) ?? TIM_t("消息加载失败");
      }
      final list = (res['messages'] as List<dynamic>? ?? [])
          .map((e) => ChatWindowMessage.fromJson(e as Map))
          .toList();
      _messages
        ..clear()
        ..addAll(_dedupe(list));
      _hasMore = res['hasMore'] as bool? ?? false;
      _error = null;
      await _request('chat.markRead', {
        'conversationID': _conversationID,
      });
    } catch (error) {
      _error = error.toString();
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _scrollToBottom();
  }

  List<ChatWindowMessage> _dedupe(List<ChatWindowMessage> list) {
    final seen = <String>{};
    return list.where((message) {
      if (message.msgID.isEmpty) return true;
      return seen.add(message.msgID);
    }).toList();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    _loadingMore = true;
    try {
      final res = await _request('chat.getMessages', {
        'conversationID': _conversationID,
        'count': 30,
        'lastMsgID': _messages.first.msgID,
      });
      if (res['ok'] == true) {
        final older = (res['messages'] as List<dynamic>? ?? [])
            .map((e) => ChatWindowMessage.fromJson(e as Map))
            .toList();
        final existing = _messages.map((e) => e.msgID).toSet();
        final fresh = older.where((e) => !existing.contains(e.msgID)).toList();
        if (mounted) {
          setState(() {
            _messages.insertAll(0, fresh);
            _hasMore = res['hasMore'] as bool? ?? false;
          });
        }
      }
    } catch (_) {}
    _loadingMore = false;
  }

  void _onNewMessage(dynamic raw) {
    if (raw is! Map) return;
    final message = ChatWindowMessage.fromJson(raw);
    final index = _messages.indexWhere(
        (e) => e.msgID.isNotEmpty && e.msgID == message.msgID);
    if (!mounted) return;
    setState(() {
      if (index >= 0) {
        _messages[index] = message;
      } else {
        _messages.add(message);
      }
    });
    _scrollToBottom();
  }

  void _onRevoked(dynamic raw) {
    if (raw is! Map) return;
    final msgID = raw['msgID'] as String?;
    if (msgID == null) return;
    final index = _messages.indexWhere((e) => e.msgID == msgID);
    if (index < 0 || !mounted) return;
    setState(() => _messages[index] = _messages[index].asRevoked());
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await _request('chat.sendText', {
        'conversationID': _conversationID,
        'text': text,
      });
      if (res['ok'] == true) {
        _input.clear();
        // 主窗口会广播新消息；这里用回包兜底，避免广播丢失时不上屏。
        if (res['message'] is Map) _onNewMessage(res['message']);
      } else {
        _toast((res['error'] as String?)?.isNotEmpty == true
            ? res['error'] as String
            : TIM_t("发送失败"));
      }
    } catch (error) {
      _toast(error.toString());
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _openInMain() async {
    try {
      await _request('chat.openInMain', const {});
      _toast(TIM_t("已切回主窗口，更多操作请在那里完成"));
    } catch (_) {}
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    try {
      await DesktopMultiWindow.invokeMethod(
          0, 'chat.closed', {'windowId': widget.windowId});
    } catch (_) {}
    await _controller.close();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final background = theme.weakBackgroundColor ?? AppColors.surfaceOf(context);
    final onSurface = theme.darkTextColor ?? AppColors.onSurfaceOf(context);
    final weak = theme.weakTextColor ?? AppColors.weakTextOf(context);
    final primary = theme.primaryColor ?? const Color(0xFF147AFF);
    final bubble =
        theme.weakDividerColor ?? AppColors.elevatedSurfaceOf(context);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _circleAvatar(_avatarUrl, _title, primary, 36),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: onSurface)),
            Text(
              widget.conversation.type == 2
                  ? TIM_t("群聊")
                  : "ID: ${widget.conversation.userID ?? ''}",
              style: TextStyle(fontSize: 11, color: weak),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.open_in_new, size: 20, color: weak),
            tooltip: TIM_t("在主窗口打开"),
            onPressed: _openInMain,
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: weak),
            tooltip: TIM_t("关闭窗口"),
            onPressed: _close,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildList(background, onSurface, weak, primary, bubble),
          ),
          _buildInput(background, onSurface, weak, primary, bubble),
        ],
      ),
    );
  }

  Widget _buildList(Color background, Color onSurface, Color weak,
      Color primary, Color bubble) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: onSurface)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadInitial();
                },
                child: Text(TIM_t("重试")),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text(TIM_t("暂无消息"),
            style: TextStyle(fontSize: 14, color: weak)),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: _messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : const SizedBox(height: 4);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _messageTile(
            _messages[index - 1],
            onSurface,
            weak,
            primary,
            bubble,
          ),
        );
      },
    );
  }

  Widget _messageTile(ChatWindowMessage message, Color onSurface, Color weak,
      Color primary, Color bubble) {
    final isSelf = message.isSelf;
    final avatar = _circleAvatar(
      isSelf ? '' : message.faceUrl,
      isSelf ? TIM_t("我") : message.nickName,
      primary,
      34,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isSelf) ...[avatar, const SizedBox(width: 8)],
        Flexible(
          child: Column(
            crossAxisAlignment:
                isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isSelf && message.nickName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 2),
                  child: Text(message.nickName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: weak)),
                ),
              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelf ? primary : bubble,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _bubbleBody(message, isSelf, onSurface, weak),
              ),
              const SizedBox(height: 3),
              Text(_formatTime(message.timestamp),
                  style: TextStyle(fontSize: 10, color: weak)),
            ],
          ),
        ),
        if (isSelf) ...[const SizedBox(width: 8), avatar],
      ],
    );
  }

  Widget _bubbleBody(ChatWindowMessage message, bool isSelf, Color onSurface,
      Color weak) {
    final textColor = isSelf ? AppColors.onPrimary : onSurface;
    switch (message.kind) {
      case 'text':
        return SelectableText(message.text,
            style: TextStyle(fontSize: 14, color: textColor));
      case 'image':
        if (message.imageUrl.isEmpty) {
          return _fallback(TIM_t("[图片]"), textColor);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.imageUrl,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _fallback(TIM_t("[图片无法显示]"), textColor),
          ),
        );
      case 'file':
        return _fallback(
          "${message.fileName.isEmpty ? TIM_t("文件") : message.fileName} · ${_formatSize(message.fileSize)}",
          textColor,
        );
      case 'revoked':
        return _fallback(TIM_t("消息已撤回"), textColor);
      default:
        return _fallback(TIM_t("[暂不支持的消息类型]"), textColor);
    }
  }

  Widget _fallback(String text, Color color) => Text(text,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: color));

  Widget _buildInput(Color background, Color onSurface, Color weak,
      Color primary, Color bubble) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: bubble, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                style: TextStyle(color: onSurface, fontSize: 14),
                cursorColor: primary,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: TIM_t("输入消息（端到端加密）"),
                  hintStyle: TextStyle(color: weak, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: bubble,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.open_in_new, color: weak),
              tooltip: TIM_t("图片、文件等更多操作在主窗口完成"),
              onPressed: _openInMain,
            ),
            IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.send, color: primary),
              tooltip: TIM_t("发送"),
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleAvatar(String? url, String name, Color primary, double size) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url != null && url.isNotEmpty
            ? Image.network(url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(name, primary))
            : _avatarFallback(name, primary),
      ),
    );
  }

  Widget _avatarFallback(String name, Color primary) => Container(
        alignment: Alignment.center,
        color: primary.withValues(alpha: 0.85),
        child: Text(
          name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
          style: const TextStyle(fontSize: 14, color: AppColors.onPrimary),
        ),
      );

  String _formatTime(int timestamp) {
    if (timestamp <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
