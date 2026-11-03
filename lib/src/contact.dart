// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_demo/src/blackList.dart';
import 'package:tencent_cloud_chat_demo/src/group_list.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _friendshipModel.loadContactListData();
  }

  Widget _buildContactList(List<TopListItem> topList, bool isWideScreen) {
    return ChangeNotifierProvider.value(
      value: _friendshipModel,
      child: Consumer<TUIFriendShipViewModel>(
        builder: (context, model, _) {
          final friends = model.friendList ?? <V2TimFriendInfo>[];
          final theme = Provider.of<DefaultThemeData>(context).theme;
          if (friends.isEmpty) {
            return ListView(
              children: [
                ...topList.map((e) => _topListBuilder(e) ?? const SizedBox()),
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      TIM_t("无联系人"),
                      style: TextStyle(color: theme.weakTextColor),
                    ),
                  ),
                )
              ],
            );
          }
          return ListView.builder(
            itemCount: topList.length + friends.length,
            itemBuilder: (context, index) {
              if (index < topList.length) {
                return _topListBuilder(topList[index]) ??
                    const SizedBox.shrink();
              }
              return _buildFriendItem(friends[index - topList.length],
                  isWideScreen, theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildFriendItem(
      V2TimFriendInfo item, bool isWideScreen, TUITheme theme) {
    final nickName = item.userProfile?.nickName ?? "";
    final friendRemark = item.friendRemark ?? "";
    final showName = friendRemark.isNotEmpty
        ? friendRemark
        : (nickName.isNotEmpty ? nickName : item.userID);
    return InkWell(
      onTap: () {
        if (widget.onTapItem != null) {
          widget.onTapItem!(item.userID);
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfile(userID: item.userID),
              ));
        }
      },
      child: Container(
        color: theme.weakBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              height: isWideScreen ? 30 : 40,
              width: isWideScreen ? 30 : 40,
              child: Avatar(
                faceUrl: item.userProfile?.faceUrl ?? "",
                showName: showName,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                showName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: theme.darkTextColor,
                    fontSize: isWideScreen ? 14 : 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _topListItemTap(String id) {
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    switch (id) {
      case "newContact":
        if (isWideScreen) {
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
              MaterialPageRoute(
                builder: (context) => const NewContact(),
              ));
        }
        break;
      case "groupList":
        if (isWideScreen) {
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupList(),
              ));
        }
        break;
      case "blackList":
        if (isWideScreen) {
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
              MaterialPageRoute(
                builder: (context) => const BlackList(),
              ));
        }
        break;
      default:
        break;
    }
  }

  String _getImagePathByID(String id) {
    final themeTypeSuffix = Provider.of<DefaultThemeData>(context)
        .currentThemeType
        .toString()
        .replaceFirst('ThemeType.', '');
    switch (id) {
      case "newContact":
        return "assets/newContact_$themeTypeSuffix.png";
      case "groupList":
        return "assets/groupList_$themeTypeSuffix.png";
      case "blackList":
        return "assets/blackList_$themeTypeSuffix.png";
      case "customerService":
        return "assets/customerService.png";
      default:
        return "";
    }
  }

  Widget? _topListBuilder(TopListItem item) {
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final showName = item.name;
    if (item.id == "newContact") {
      return InkWell(
        onTap: () {
          _topListItemTap(item.id);
        },
        child: Container(
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: theme.weakDividerColor ?? hexToColor("DBDBDB")))),
          padding: const EdgeInsets.only(top: 12, left: 16, bottom: 12),
          child: Row(
            children: [
              Container(
                height: isWideScreen ? 30 : 40,
                width: isWideScreen ? 30 : 40,
                margin: const EdgeInsets.only(right: 12),
                child: Avatar(
                  faceUrl: _getImagePathByID(item.id),
                  showName: showName,
                  isFromLocalAsset: true,
                ),
              ),
              Expanded(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    showName,
                    style: TextStyle(
                        color: theme.darkTextColor ?? hexToColor("111111"),
                        fontSize: isWideScreen ? 14 : 18),
                  ),
                  Expanded(child: Container()),
                  const TIMUIKitUnreadCount(),
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.keyboard_arrow_right,
                      color: theme.weakTextColor ?? hexToColor('BBBBBB'),
                    ),
                  )
                ],
              ))
            ],
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final topList = [
      TopListItem(
          name: TIM_t("新的联系人"),
          id: "newContact",
          icon: Image.asset(_getImagePathByID("newContact")),
          onTap: () {
            _topListItemTap("newContact");
          }),
      if (!isWideScreen)
        TopListItem(
            name: TIM_t("我的群聊"),
            id: "groupList",
            icon: Image.asset(_getImagePathByID("groupList")),
            onTap: () {
              _topListItemTap("groupList");
            }),
      TopListItem(
          name: TIM_t("黑名单"),
          id: "blackList",
          icon: Image.asset(_getImagePathByID("blackList")),
          onTap: () {
            _topListItemTap("blackList");
          }),
    ];

    return Column(
      children: [
        Expanded(child: _buildContactList(topList, isWideScreen))
      ],
    );
  }
}
