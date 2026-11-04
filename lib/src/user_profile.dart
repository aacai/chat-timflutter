import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/chat.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/search.dart';
import 'package:tencent_cloud_chat_demo/src/tencent_page.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_profile_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

class UserProfile extends StatefulWidget {
  final String userID;
  final ValueChanged<V2TimConversation>? onClickSendMessage;
  final ValueChanged<String>? onRemarkUpdate;

  const UserProfile({
    Key? key,
    required this.userID,
    this.onRemarkUpdate,
    this.onClickSendMessage,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => UserProfileState();
}

class UserProfileState extends State<UserProfile> {
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    return TencentPage(
      child: Scaffold(
        backgroundColor: theme.weakBackgroundColor,
        appBar: isWideScreen
            ? null
            : AppBar(
                elevation: 0,
                backgroundColor: theme.weakBackgroundColor,
                centerTitle: true,
                title: Text(
                  TIM_t("详细资料"),
                  style: TextStyle(
                    color: theme.darkTextColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                iconTheme: IconThemeData(color: theme.darkTextColor),
              ),
        body: Column(
          children: [
            if (isWideScreen)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 36),
                child: MoveWindow(
                  child: Container(color: theme.weakBackgroundColor),
                ),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ProfileBody(
                    userID: widget.userID,
                    onRemarkUpdate: widget.onRemarkUpdate,
                    onClickSendMessage: widget.onClickSendMessage,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      name: "friendProfile",
    );
  }
}

class ProfileBody extends StatefulWidget {
  final String userID;
  final ValueChanged<String>? onRemarkUpdate;
  final ValueChanged<V2TimConversation>? onClickSendMessage;
  final VoidCallback? onClose;
  final bool compact;

  const ProfileBody({
    Key? key,
    required this.userID,
    this.onRemarkUpdate,
    this.onClickSendMessage,
    this.onClose,
    this.compact = false,
  }) : super(key: key);

  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody> {
  final TUIProfileViewModel _model = TUIProfileViewModel();
  final _sdk = TIMUIKitCore.getSDKInstance();

  V2TimUserFullInfo? _extraInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
    _load();
  }

  @override
  void didUpdateWidget(ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userID != widget.userID) {
      _load();
    }
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    _model.dispose();
    super.dispose();
  }

  void _onModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await serviceLocator<TUIFriendShipViewModel>().loadBlockListData();
      await _model.loadData(userID: widget.userID);
    } catch (e) {
      debugPrint("profile load failed: $e");
    }

    final friendProfile = _model.userProfile?.friendInfo?.userProfile;
    if (friendProfile == null) {
      final res = await _sdk.getUsersInfo(userIDList: [widget.userID]);
      _extraInfo = res.data?.isNotEmpty == true ? res.data!.first : null;
    } else {
      _extraInfo = friendProfile;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  V2TimUserFullInfo? get _info =>
      _model.userProfile?.friendInfo?.userProfile ?? _extraInfo;

  String get _showName {
    final remark = _model.userProfile?.friendInfo?.friendRemark ?? '';
    if (remark.isNotEmpty) {
      return remark;
    }
    final nick = _info?.nickName ?? '';
    return nick.isNotEmpty ? nick : widget.userID;
  }

  String get _conversationID => "c2c_${widget.userID}";

  V2TimConversation get _conversation {
    final conv = _model.userProfile?.conversation;
    if (conv != null) {
      return conv;
    }
    return V2TimConversation(
      conversationID: _conversationID,
      userID: widget.userID,
      type: 1,
      showName: _showName,
      faceUrl: _info?.faceUrl ?? '',
    );
  }

  String _genderText(int? gender) {
    if (gender == 1) {
      return TIM_t("男");
    }
    if (gender == 2) {
      return TIM_t("女");
    }
    return TIM_t("未填写");
  }

  String _birthdayText(int? birthday) {
    if (birthday == null || birthday == 0) {
      return TIM_t("未填写");
    }
    final str = birthday.toString();
    if (str.length == 8) {
      return "${str.substring(0, 4)}-${str.substring(4, 6)}-${str.substring(6, 8)}";
    }
    return str;
  }

  Future<void> _editRemark() async {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final controller = TextEditingController(
      text: _model.userProfile?.friendInfo?.friendRemark ?? '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.weakBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(TIM_t("设置备注"),
            style: TextStyle(color: theme.darkTextColor, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: theme.darkTextColor),
          decoration: InputDecoration(
            hintText: TIM_t("请输入备注"),
            hintStyle: TextStyle(color: theme.weakTextColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TIM_t("取消")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(TIM_t("保存")),
          ),
        ],
      ),
    );
    if (value == null) {
      return;
    }
    final res = await _model.updateRemarks(widget.userID, value);
    if (res.code == 0) {
      widget.onRemarkUpdate?.call(value);
    }
  }

  Future<void> _setPinned(bool value) async {
    if (_model.userProfile?.conversation != null) {
      await _model.pinedConversation(value, _conversationID);
      return;
    }
    await _sdk.getConversationManager().pinConversation(
          conversationID: _conversationID,
          isPinned: value,
        );
    setState(() {});
  }

  Future<void> _sendMessage() async {
    final conversation = _conversation;
    if (widget.onClickSendMessage != null) {
      widget.onClickSendMessage!(conversation);
      widget.onClose?.call();
      return;
    }
    widget.onClose?.call();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Chat(selectedConversation: conversation),
      ),
    );
  }

  void _searchChat() {
    final conversation = _conversation;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Search(
          conversation: conversation,
          onTapConversation: (V2TimConversation conv,
              [V2TimMessage? targetMsg]) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Chat(
                  selectedConversation: conv,
                  initFindingMsg: targetMsg,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteFriend() async {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.weakBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(TIM_t("确定删除该好友吗？"),
            style: TextStyle(color: theme.darkTextColor, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(TIM_t("取消")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(TIM_t("删除")),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _model.deleteFriend(widget.userID);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = theme.primaryColor ?? const Color(0xFF147AFF);
    final bg = theme.weakBackgroundColor ??
        (isDark ? const Color(0xFF16181C) : const Color(0xFFF5F6F8));
    final surface = Color.lerp(
            bg, isDark ? AppColors.onPrimary : Colors.black, isDark ? 0.05 : 0.035) ??
        bg;
    final divider = theme.weakDividerColor ??
        AppColors.dividerOf(context);
    final primaryText = theme.darkTextColor ??
        AppColors.onSurfaceOf(context);
    final secondaryText = theme.weakTextColor ??
        AppColors.weakTextOf(context);
    final danger = theme.cautionColor ?? const Color(0xFFE5484D);
    final compact = widget.compact;
    final colors = _Palette(
      background: bg,
      surface: surface,
      divider: divider,
      primary: primary,
      primaryText: primaryText,
      secondaryText: secondaryText,
      danger: danger,
    );

    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: primary),
          ),
        ),
      );
    }

    final friendInfo = _model.userProfile?.friendInfo;
    final isFriend = _model.friendType != 0;
    final isPinned = _model.userProfile?.conversation?.isPinned ?? false;
    final isMute = _model.isDisturb ?? false;
    final isBlocked = _model.isAddToBlackList ?? false;
    final remark = friendInfo?.friendRemark ?? '';
    final publicKey = _info?.selfSignature ?? '';
    final groups = friendInfo?.friendGroups ?? const <String>[];

    final rows = <_InfoRowData>[
      _InfoRowData("备注", remark.isEmpty ? "未填写" : remark,
          onTap: _editRemark),
      _InfoRowData("昵称", _nonEmpty(_info?.nickName)),
      _InfoRowData("用户 ID", widget.userID, copyable: true),
      _InfoRowData("性别", _genderText(_info?.gender)),
      _InfoRowData("生日", _birthdayText(_info?.birthday)),
      _InfoRowData("等级", _nonEmpty(_info?.level?.toString())),
      _InfoRowData("角色", _nonEmpty(_info?.role?.toString())),
      _InfoRowData("加好友验证", _allowTypeText(_info?.allowType)),
      _InfoRowData("好友分组", groups.isEmpty ? "无" : groups.join("、")),
    ];
    _info?.customInfo?.forEach((key, value) {
      rows.add(_InfoRowData(key, value.isEmpty ? "未填写" : value));
    });
    friendInfo?.friendCustomInfo?.forEach((key, value) {
      rows.add(_InfoRowData(key, value.isEmpty ? "未填写" : value));
    });

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          compact ? 16 : 20, compact ? 16 : 20, compact ? 16 : 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _identityCard(colors, compact, isFriend),
          const SizedBox(height: 24),
          _SectionLabel("基本信息", secondaryText),
          const SizedBox(height: 8),
          _surfaceCard(
              colors, rows.map((e) => _infoRow(colors, e)).toList()),
          const SizedBox(height: 24),
          _SectionLabel("加密信息", secondaryText),
          const SizedBox(height: 8),
          _keyCard(colors, publicKey),
          const SizedBox(height: 24),
          _SectionLabel("聊天设置", secondaryText),
          const SizedBox(height: 8),
          _surfaceCard(colors, [
            _switchRow(colors, "置顶聊天", isPinned, _setPinned),
            _switchRow(colors, "消息免打扰", isMute,
                (value) => _model.setMessageDisturb(widget.userID, value)),
            _switchRow(colors, "加入黑名单", isBlocked,
                (value) => _model.addToBlackList(value, widget.userID)),
            _actionRow(colors, "搜索聊天记录", _searchChat),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _sendMessage,
              child: const Text("发消息",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isFriend ? danger : primary,
                side: BorderSide(
                    color: (isFriend ? danger : primary).withOpacity(0.55)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isFriend
                  ? _deleteFriend
                  : () => _model.addFriend(widget.userID),
              child: Text(isFriend ? "删除好友" : "加为好友",
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  String _nonEmpty(String? value) {
    if (value == null || value.isEmpty || value == '0') {
      return "未填写";
    }
    return value;
  }

  String _allowTypeText(int? allowType) {
    switch (allowType) {
      case 0:
        return "允许任何人";
      case 1:
        return "需要验证";
      case 2:
        return "拒绝加好友";
      default:
        return "未设置";
    }
  }

  void _copy(String text) {
    if (text.isEmpty) {
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ToastUtils.toast("已复制");
  }

  Widget _identityCard(_Palette c, bool compact, bool isFriend) {
    final nick = _info?.nickName ?? '';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 60 : 68,
                height: compact ? 60 : 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.divider, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Avatar(
                    faceUrl: _info?.faceUrl ?? '', showName: _showName),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_showName,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: c.primaryText)),
                    if (nick.isNotEmpty && nick != _showName) ...[
                      const SizedBox(height: 4),
                      Text("昵称：$nick",
                          style: TextStyle(
                              fontSize: 13, color: c.secondaryText)),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(isFriend ? "好友" : "非好友",
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: c.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text("ID",
                    style: TextStyle(fontSize: 12, color: c.secondaryText)),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(widget.userID,
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: c.primaryText)),
                ),
                InkWell(
                  onTap: () => _copy(widget.userID),
                  child: Icon(Icons.copy_rounded,
                      size: 15, color: c.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyCard(_Palette c, String key) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_rounded, size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text("端到端加密公钥",
                  style: TextStyle(fontSize: 13, color: c.secondaryText)),
              const Spacer(),
              InkWell(
                onTap: () => _copy(key),
                child: Row(children: [
                  Icon(Icons.copy_rounded, size: 14, color: c.primary),
                  const SizedBox(width: 4),
                  Text("复制",
                      style: TextStyle(fontSize: 12, color: c.primary)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            key.isEmpty ? "暂无公钥" : key,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              fontFamily: 'monospace',
              color: key.isEmpty ? c.secondaryText : c.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard(_Palette c, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  endIndent: 16,
                  color: c.divider),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _infoRow(_Palette c, _InfoRowData data) {
    return InkWell(
      onTap: data.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(data.label,
                    style:
                        TextStyle(fontSize: 13, color: c.secondaryText)),
              ),
              Expanded(
                child: Text(data.value,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 14, color: c.primaryText)),
              ),
              if (data.copyable) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _copy(data.value),
                  child: Icon(Icons.copy_rounded,
                      size: 14, color: c.primary),
                ),
              ],
              if (data.onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: c.secondaryText),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchRow(_Palette c, String label, bool value,
      ValueChanged<bool> onChanged) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: c.primaryText)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: c.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow(_Palette c, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 14, color: c.primaryText)),
              ),
              Icon(Icons.chevron_right, size: 16, color: c.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _Palette {
  final Color background;
  final Color surface;
  final Color divider;
  final Color primary;
  final Color primaryText;
  final Color secondaryText;
  final Color danger;

  const _Palette({
    required this.background,
    required this.surface,
    required this.divider,
    required this.primary,
    required this.primaryText,
    required this.secondaryText,
    required this.danger,
  });
}

class _InfoRowData {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool copyable;

  const _InfoRowData(this.label, this.value,
      {this.onTap, this.copyable = false});
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel(this.text, this.color, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}
