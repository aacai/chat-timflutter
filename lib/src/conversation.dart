import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_window.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/chat.dart';
import 'package:tencent_cloud_chat_demo/src/create_group.dart';
import 'package:tencent_cloud_chat_demo/src/create_group_introduction.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/user_guide.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_conversation_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

GlobalKey<_ConversationState> conversationKey = GlobalKey();

class Conversation extends StatefulWidget {
  final TIMUIKitConversationController conversationController;
  final ValueChanged<V2TimConversation?>? onConversationChanged;
  final VoidCallback? onClickSearch;
  final VoidCallback? onClickPlus;
  final V2TimConversation? selectedConversation;

  const Conversation({
    Key? key,
    required this.conversationController,
    this.onConversationChanged,
    this.onClickSearch,
    this.onClickPlus,
    this.selectedConversation,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ConversationState();
}

class _ConversationState extends State<Conversation> {
  final V2TIMManager _sdk = TIMUIKitCore.getSDKInstance();
  final TextEditingController _searchController = TextEditingController();

  List<V2TimConversation> _conversations = [];
  String _keyword = '';
  String? _selectedId;
  Timer? _pollTimer;
  V2TimConversationListener? _listener;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedConversation?.conversationID;
    _listener = V2TimConversationListener(
      onConversationChanged: (_) => _load(),
      onNewConversation: (_) => _load(),
    );
    _sdk.getConversationManager().addConversationListener(listener: _listener!);
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void didUpdateWidget(Conversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedConversation?.conversationID !=
        oldWidget.selectedConversation?.conversationID) {
      _selectedId = widget.selectedConversation?.conversationID;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_listener != null) {
      _sdk.getConversationManager()
          .removeConversationListener(listener: _listener!);
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await _sdk
        .getConversationManager()
        .getConversationList(nextSeq: '', count: 40);
    final list = res.data?.conversationList;
    if (!mounted || list == null) {
      return;
    }
    setState(() {
      _conversations = list;
    });
  }

  void scrollToNextUnreadConversation() {
    for (final conversation in _conversations) {
      if ((conversation.unreadCount ?? 0) > 0) {
        setState(() {
          _selectedId = conversation.conversationID;
        });
        widget.onConversationChanged?.call(conversation);
        return;
      }
    }
  }

  Future<void> _handleTap(V2TimConversation conversation) async {
    setState(() {
      _selectedId = conversation.conversationID;
    });
    if (widget.onConversationChanged != null) {
      widget.onConversationChanged!(conversation);
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Chat(selectedConversation: conversation),
        ),
      );
    }
  }

  Future<void> _showItemMenu(V2TimConversation conversation) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MenuSheet(
        conversation: conversation,
        showOpenInWindow: ChatWindowManager.isSupported,
      ),
    );
    if (action == null || !mounted) {
      return;
    }
    if (action == 'window') {
      await ChatWindowManager.instance.open(conversation);
      return;
    }
    final manager = _sdk.getConversationManager();
    if (action == 'pin') {
      await manager.pinConversation(
        conversationID: conversation.conversationID,
        isPinned: !(conversation.isPinned ?? false),
      );
    } else if (action == 'delete') {
      await manager.deleteConversation(
          conversationID: conversation.conversationID);
    } else if (action == 'draft') {
      await manager.setConversationDraft(
        conversationID: conversation.conversationID,
        draftText: '',
      );
    }
    _load();
  }

  void _showPlusMenu() {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MenuSheet(
        conversation: null,
      ),
    ).then((action) {
      if (!mounted || action == null) {
        return;
      }
      if (action == 'single') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                const CreateGroup(convType: GroupTypeForUIKit.single),
          ),
        );
      } else if (action == 'group') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CreateGroupIntroduction(),
          ),
        );
      }
    });
  }

  List<V2TimConversation> get _filtered {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _conversations;
    }
    return _conversations.where((e) {
      final name = (e.showName ?? '').toLowerCase();
      final id = (e.userID ?? e.groupID ?? '').toLowerCase();
      return name.contains(keyword) || id.contains(keyword);
    }).toList();
  }

  String _timeText(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return '';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return "$hh:$mm";
    }
    if (date.year == now.year) {
      return "${date.month}/${date.day}";
    }
    return "${date.year}/${date.month}/${date.day}";
  }

  String _previewText(V2TimConversation conversation) {
    final draft = conversation.draftText;
    if (draft != null && draft.isNotEmpty) {
      return "${TIM_t("[草稿]")} $draft";
    }
    final message = conversation.lastMessage;
    if (message == null) {
      return '';
    }
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return message.textElem?.text ?? '';
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return TIM_t("[图片]");
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        return TIM_t("[文件]");
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return TIM_t("[语音]");
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return TIM_t("[视频]");
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return TIM_t("[自定义消息]");
      default:
        return TIM_t("[消息]");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = theme.primaryColor ?? const Color(0xFF147AFF);
    final list = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.overlayOf(context)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search,
                          size: 16, color: theme.weakTextColor ?? Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                              fontSize: 13, color: theme.darkTextColor),
                          cursorColor: primary,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: TIM_t("搜索"),
                            hintStyle: TextStyle(
                                fontSize: 13,
                                color: theme.weakTextColor ?? Colors.grey),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _keyword = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _RoundIconButton(
                icon: Icons.add,
                color: primary,
                onTap: _showPlusMenu,
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? _EmptyHint(text: TIM_t("暂无会话"))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    return _buildItem(list[index], theme, primary, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildItem(
    V2TimConversation conversation,
    dynamic theme,
    Color primary,
    bool isDark,
  ) {
    final selected = conversation.conversationID == _selectedId;
    final name = conversation.showName ??
        (conversation.type == 1
            ? conversation.userID
            : conversation.groupID) ??
        '';
    final unread = conversation.unreadCount ?? 0;
    final preview = _previewText(conversation);

    return GestureDetector(
      onLongPress: () => _showItemMenu(conversation),
      onSecondaryTap: () => _showItemMenu(conversation),
      child: InkWell(
        onTap: () => _handleTap(conversation),
        child: Container(
          color: selected ? primary.withOpacity(0.10) : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: Avatar(
                      faceUrl: conversation.faceUrl ?? '',
                      showName: name,
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF584C),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: theme.weakBackgroundColor ?? AppColors.surfaceOf(context),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (conversation.isPinned == true) ...[
                          Icon(Icons.push_pin,
                              size: 12, color: theme.weakTextColor),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: theme.darkTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeText(conversation.lastMessage?.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.weakTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: unread > 0
                                  ? (theme.darkTextColor ?? Colors.black)
                                  : theme.weakTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundIconButton({
    Key? key,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _MenuSheet extends StatelessWidget {
  final V2TimConversation? conversation;
  final bool showOpenInWindow;

  const _MenuSheet({
    Key? key,
    this.conversation,
    this.showOpenInWindow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isGroup = conversation != null;

    List<Widget> items;
    if (isGroup) {
      items = [
        if (showOpenInWindow)
          _MenuItem(
            icon: Icons.open_in_new,
            label: TIM_t("在独立窗口打开"),
            value: 'window',
          ),
        _MenuItem(
          icon: Icons.push_pin,
          label: conversation!.isPinned == true
              ? TIM_t("取消置顶")
              : TIM_t("置顶"),
          value: 'pin',
        ),
        _MenuItem(
          icon: Icons.delete_outline,
          label: TIM_t("删除会话"),
          value: 'delete',
          danger: true,
        ),
      ];
    } else {
      items = [
        _MenuItem(
          icon: Icons.chat_bubble_outline,
          label: TIM_t("发起会话"),
          value: 'single',
        ),
        _MenuItem(
          icon: Icons.group_add_outlined,
          label: TIM_t("创建群聊"),
          value: 'group',
        ),
      ];
    }

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.weakBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                color: theme.weakDividerColor,
              ),
            items[i],
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  const _MenuItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final color = danger
        ? (theme.cautionColor ?? const Color(0xFFFF584C))
        : (theme.darkTextColor ?? Colors.black);
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(fontSize: 14.5, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 40, color: (theme.weakTextColor ?? Colors.grey).withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: theme.weakTextColor),
          ),
        ],
      ),
    );
  }
}
