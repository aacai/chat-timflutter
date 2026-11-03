import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_result_item.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_result_item.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/tencent_page.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/theme_profile_widgets.dart';

class Search extends StatefulWidget {
  const Search(
      {Key? key,
      this.isAutoFocus = true,
      this.conversation,
      required this.onTapConversation,
      this.initKeyword,
      this.onBack})
      : super(key: key);

  /// if assign a specific conversation, it will only search in it; otherwise search globally
  final V2TimConversation? conversation;

  final VoidCallback? onBack;

  /// the callback after clicking the conversation item to specific message in it
  final Function(V2TimConversation, V2TimMessage?) onTapConversation;

  /// initial keyword for detail search
  final String? initKeyword;

  final bool? isAutoFocus;

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  final model = serviceLocator<TUISearchViewModel>();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late String _keyword;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _keyword = widget.initKeyword ?? "";
    _controller.text = _keyword;
    model.initSearch();
    if (widget.conversation == null) {
      model.initConversationMsg();
    } else if (_keyword.isNotEmpty) {
      model.getMsgForConversation(
          _keyword, widget.conversation!.conversationID, 0);
    }
    _controller.addListener(() {
      final v = _controller.text;
      if (widget.conversation == null) {
        model.searchByKey(v);
      } else {
        _updateMsgResult(v, true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateMsgResult(String? keyword, bool isNewSearch) {
    if (isNewSearch) {
      _currentPage = 0;
      _keyword = keyword ?? _keyword;
    }
    model.getMsgForConversation(
        _keyword, widget.conversation!.conversationID, _currentPage);
    _currentPage++;
    setState(() {});
  }

  (bool, bool) _isRevokeMessage(V2TimMessage? message) {
    if (message == null) return (false, false);
    if (message.status == 6) return (true, false);
    try {
      final customData = jsonDecode(message.cloudCustomData ?? "{}");
      final isRevoke = customData["isRevoke"] ?? false;
      final revokeByAdmin = customData["revokeByAdmin"] ?? false;
      return (isRevoke, revokeByAdmin);
    } catch (e) {
      return (false, false);
    }
  }

  String _getMsgElem(V2TimMessage message) {
    final msgType = message.elemType;
    final revoke = _isRevokeMessage(message);
    if (revoke.$1) {
      final isSelf = message.isSelf ?? true;
      final option2 = revoke.$2
          ? TIM_t("管理员")
          : (isSelf ? TIM_t("您") : (message.nickName ?? message.sender));
      return TIM_t_para("{{option2}}撤回了一条消息", "$option2撤回了一条消息")(
          option2: option2);
    }
    switch (msgType) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return TIM_t("[自定义]");
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return TIM_t("[语音]");
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return message.textElem?.text ?? "";
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return TIM_t("[表情]");
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        final option1 = message.fileElem?.fileName ?? "";
        return TIM_t_para("[文件] {{option1}}", "[文件] $option1")(
            option1: option1);
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return TIM_t("[图片]");
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return TIM_t("[视频]");
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return TIM_t("[位置]");
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return TIM_t("[聊天记录]");
      default:
        return TIM_t("未知消息");
    }
  }

  String _formatTime(int? ts) {
    if (ts == null) return "";
    return TimeAgo().getTimeForMessage(ts);
  }

  String _friendShowName(V2TimFriendInfoResult friend) {
    final f = friend.friendInfo;
    if (f?.friendRemark != null && f!.friendRemark!.isNotEmpty) {
      return f.friendRemark!;
    }
    if (f?.userProfile?.nickName != null &&
        f!.userProfile!.nickName!.isNotEmpty) {
      return f.userProfile!.nickName!;
    }
    return f?.userID ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final isConversation = widget.conversation != null;
    return TencentPage(
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          backgroundColor: theme.primaryColor,
          title: Text(
            isConversation
                ? (widget.conversation?.showName ??
                    widget.conversation?.conversationID ??
                    TIM_t("相关聊天记录"))
                : TIM_t("全局搜索"),
            style: const TextStyle(color: Colors.white, fontSize: 17),
          ),
        ),
        body: ChangeNotifierProvider.value(
          value: model,
          child: Column(
            children: [
              _buildSearchInput(theme),
              Expanded(
                child: isConversation
                    ? _buildMsgDetail(context, theme)
                    : _buildGlobal(context, theme),
              ),
            ],
          ),
        ),
      ),
      name: 'search',
    );
  }

  Widget _buildSearchInput(TUITheme theme) {
    return Container(
      color: theme.weakBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.weakBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.isAutoFocus ?? true,
          style: TextStyle(color: theme.darkTextColor),
          decoration: InputDecoration(
            hintText: TIM_t("搜索"),
            hintStyle: TextStyle(color: theme.weakTextColor),
            prefixIcon:
                Icon(Icons.search, size: 18, color: theme.weakTextColor),
            suffixIcon: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => _controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: Icon(Icons.clear, color: theme.weakTextColor),
                      onPressed: _controller.clear,
                    ),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _folderTitle(TUITheme theme, String name) {
    return Container(
      color: theme.weakBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(name,
          style: TextStyle(color: theme.weakTextColor, fontSize: 13)),
    );
  }

  Widget _moreButton(TUITheme theme, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: theme.weakBackgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(text, style: TextStyle(color: theme.weakTextColor)),
      ),
    );
  }

  Widget _emptyHint(TUITheme theme) {
    return Container(
      color: theme.weakBackgroundColor,
      padding: const EdgeInsets.only(top: 80),
      alignment: Alignment.center,
      child: Text(TIM_t("搜索联系人、群聊、聊天记录"),
          style: TextStyle(color: theme.weakTextColor)),
    );
  }

  Widget _buildGlobal(BuildContext context, TUITheme theme) {
    return Consumer<TUISearchViewModel>(builder: (context, m, _) {
      final convList = m.conversationList;

      final friends = (m.friendList ?? []).where((f) {
        final idx =
            convList.indexWhere((c) => f.friendInfo?.userID == c?.userID);
        return idx != -1;
      }).map((f) {
        final idx =
            convList.indexWhere((c) => f.friendInfo?.userID == c?.userID);
        return MapEntry(f, convList[idx]!);
      }).toList();

      final groups = (m.groupList ?? []).where((g) {
        final idx = convList.indexWhere((c) => g.groupID == c?.groupID);
        return idx != -1;
      }).map((g) {
        final idx = convList.indexWhere((c) => g.groupID == c?.groupID);
        return MapEntry(g, convList[idx]!);
      }).toList();

      final msgs = (m.msgList ?? [])
          .where((item) =>
              item != null &&
              convList
                      .indexWhere((c) => c?.conversationID == item!.conversationID) !=
                  -1)
          .cast<V2TimMessageSearchResultItem>()
          .map((item) {
        final idx = convList
            .indexWhere((c) => c?.conversationID == item.conversationID);
        return MapEntry(item, convList[idx]!);
      }).toList();

      return ListView(
        children: [
          if (friends.isNotEmpty) ...[
            _folderTitle(theme, TIM_t("联系人")),
            ...friends.map((e) => ThemeListItem(
                  showName: _friendShowName(e.key),
                  faceUrl: e.key.friendInfo?.userProfile?.faceUrl,
                  subtitle: e.key.friendInfo?.userID,
                  onTap: () => widget.onTapConversation(e.value, null),
                )),
          ],
          if (groups.isNotEmpty) ...[
            _folderTitle(theme, TIM_t("群聊")),
            ...groups.map((e) => ThemeListItem(
                  showName: e.value.showName ?? e.key.groupName ?? e.key.groupID ?? "",
                  faceUrl: e.value.faceUrl ?? e.key.faceUrl,
                  subtitle: e.key.groupID,
                  onTap: () => widget.onTapConversation(e.value, null),
                )),
          ],
          if (msgs.isNotEmpty) ...[
            _folderTitle(theme, TIM_t("聊天记录")),
            ...msgs.map((e) => ThemeListItem(
                  showName: e.value.showName ?? "",
                  faceUrl: e.value.faceUrl,
                  subtitle: TIM_t_para("{{option1}}条相关聊天记录",
                      "${e.key.messageCount}条相关聊天记录")(
                      option1: e.key.messageCount),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Search(
                        onTapConversation: widget.onTapConversation,
                        conversation: e.value,
                        initKeyword: _keyword,
                      ),
                    ),
                  ),
                )),
            if (m.totalMsgCount > msgs.length)
              _moreButton(theme, TIM_t("更多聊天记录"),
                  () => m.searchMsgByKey(_keyword, false)),
          ],
          if (friends.isEmpty &&
              groups.isEmpty &&
              msgs.isEmpty &&
              _keyword.isEmpty)
            _emptyHint(theme),
        ],
      );
    });
  }

  Widget _buildMsgDetail(BuildContext context, TUITheme theme) {
    return Consumer<TUISearchViewModel>(builder: (context, m, _) {
      final msgList = m.currentMsgListForConversation;
      final total = m.totalMsgInConversationCount;
      return ListView(
        children: [
          ...msgList.map((message) => ThemeListItem(
                showName: TencentUtils.checkString(message.nickName) ??
                    TencentUtils.checkString(message.userID) ??
                    message.sender ??
                    "",
                faceUrl: message.faceUrl,
                subtitle: _getMsgElem(message),
                trailing: Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(color: theme.weakTextColor, fontSize: 12),
                ),
                onTap: () =>
                    widget.onTapConversation(widget.conversation!, message),
              )),
          if (_keyword.isNotEmpty && total > msgList.length)
            _moreButton(theme, TIM_t("更多聊天记录"),
                () => _updateMsgResult(null, false)),
          if (msgList.isEmpty && _keyword.isEmpty) _emptyHint(theme),
        ],
      );
    });
  }
}
