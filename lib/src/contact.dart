import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/add_friend.dart';
import 'package:tencent_cloud_chat_demo/src/add_group.dart';
import 'package:tencent_cloud_chat_demo/src/blackList.dart';
import 'package:tencent_cloud_chat_demo/src/group_list.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'newContact.dart';

class Contact extends StatefulWidget {
  final ValueChanged<String>? onTapItem;

  const Contact({Key? key, this.onTapItem}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ContactState();
}

class _ContactState extends State<Contact> {
  final TUIFriendShipViewModel _friendshipModel =
      serviceLocator<TUIFriendShipViewModel>();
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _friendshipModel.loadContactListData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isWideScreen =>
      TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

  String _showName(V2TimFriendInfo item) {
    final remark = item.friendRemark ?? "";
    if (remark.isNotEmpty) {
      return remark;
    }
    final nickName = item.userProfile?.nickName ?? "";
    return nickName.isNotEmpty ? nickName : item.userID;
  }

  void _openContact(V2TimFriendInfo item) {
    if (widget.onTapItem != null) {
      widget.onTapItem!(item.userID);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfile(userID: item.userID),
        ),
      );
    }
  }

  void _openNewContact() {
    if (_isWideScreen) {
      TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.addNewContact,
        context: context,
        width: MediaQuery.of(context).size.width * 0.6,
        title: TIM_t("新的联系人"),
        height: MediaQuery.of(context).size.height * 0.6,
        child: (onClose) => const NewContact(),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NewContact()),
      );
    }
  }

  void _openGroupList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GroupList()),
    );
  }

  void _openBlackList() {
    if (_isWideScreen) {
      TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.showBlockedUsers,
        context: context,
        width: MediaQuery.of(context).size.width * 0.6,
        title: TIM_t("黑名单"),
        height: MediaQuery.of(context).size.height * 0.6,
        child: (onClose) => const BlackList(),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BlackList()),
      );
    }
  }

  void _openAddFriend() {
    if (_isWideScreen) {
      TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.addFriend,
        context: context,
        width: MediaQuery.of(context).size.width * 0.3,
        title: TIM_t("添加好友"),
        height: MediaQuery.of(context).size.height * 0.5,
        child: (closeFunc) => AddFriend(closeFunc: closeFunc),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddFriend()),
      );
    }
  }

  void _openAddGroup() {
    if (_isWideScreen) {
      TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.addGroup,
        context: context,
        width: MediaQuery.of(context).size.width * 0.3,
        title: TIM_t("添加群聊"),
        height: MediaQuery.of(context).size.height * 0.5,
        child: (closeFunc) => const AddGroup(),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddGroup()),
      );
    }
  }

  Widget _buildSearchBar(TUITheme theme, Color primary, bool isDark) {
    return Padding(
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
                      style:
                          TextStyle(fontSize: 13, color: theme.darkTextColor),
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
          InkWell(
            onTap: () {
              showModalBottomSheet<String>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) => _ActionSheet(
                  actions: [
                    (Icons.person_add_alt, TIM_t("添加好友"), 'friend'),
                    (Icons.group_add_outlined, TIM_t("添加群聊"), 'group'),
                  ],
                ),
              ).then((value) {
                if (!mounted || value == null) {
                  return;
                }
                if (value == 'friend') {
                  _openAddFriend();
                } else if (value == 'group') {
                  _openAddGroup();
                }
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, size: 18, color: primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(TUITheme theme, Color primary) {
    final entries = [
      (Icons.person_add_alt, TIM_t("新的联系人"), _openNewContact),
      (Icons.forum_outlined, TIM_t("我的群聊"), _openGroupList),
      (Icons.block_outlined, TIM_t("黑名单"), _openBlackList),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        color: theme.weakBackgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 52,
              color: theme.weakDividerColor,
            ),
          InkWell(
            onTap: entries[i].$3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(entries[i].$1, size: 17, color: primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entries[i].$2,
                      style: TextStyle(
                          fontSize: 14.5, color: theme.darkTextColor),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 18, color: theme.weakTextColor),
                ],
              ),
            ),
          ),
          ],
        ],
        ),
      );
  }

  Widget _buildFriendItem(V2TimFriendInfo item, TUITheme theme) {
    final showName = _showName(item);
    return InkWell(
      onTap: () => _openContact(item),
      child: Container(
        color: theme.weakBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: Avatar(
                faceUrl: item.userProfile?.faceUrl ?? '',
                showName: showName,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                showName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.darkTextColor, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(TUITheme theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline,
                size: 36,
                color: (theme.weakTextColor ?? Colors.grey).withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(TIM_t("没有找到联系人"),
                style:
                    TextStyle(fontSize: 13, color: theme.weakTextColor)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = theme.primaryColor ?? const Color(0xFF147AFF);

    return ChangeNotifierProvider.value(
      value: _friendshipModel,
      child: Consumer<TUIFriendShipViewModel>(
        builder: (context, model, _) {
          final friends = model.friendList ?? <V2TimFriendInfo>[];
          final keyword = _keyword.trim().toLowerCase();
          final visible = keyword.isEmpty
              ? friends
              : friends.where((e) {
                  final name = _showName(e).toLowerCase();
                  return name.contains(keyword) ||
                      e.userID.toLowerCase().contains(keyword);
                }).toList();

          return Column(
            children: [
              _buildSearchBar(theme, primary, isDark),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _buildEntryCard(theme, primary),
                    for (final friend in visible)
                      _buildFriendItem(friend, theme),
                    if (visible.isEmpty) _emptyHint(theme),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  final List<(IconData, String, String)> actions;

  const _ActionSheet({Key? key, required this.actions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
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
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                color: theme.weakDividerColor,
              ),
            InkWell(
              onTap: () => Navigator.of(context).pop(actions[i].$3),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Icon(actions[i].$1,
                        size: 18, color: theme.darkTextColor),
                    const SizedBox(width: 12),
                    Text(
                      actions[i].$2,
                      style: TextStyle(
                          fontSize: 14.5, color: theme.darkTextColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
