import 'package:flutter/cupertino.dart' show showCupertinoModalPopup, CupertinoActionSheet, CupertinoActionSheetAction;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/tencent_page.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/theme_profile_widgets.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/group_profile_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitAddFriend/tim_uikit_send_application.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_ui_group_profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_demo/src/chat.dart';
import 'package:tencent_cloud_chat_demo/src/search.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';

class GroupProfilePage extends StatelessWidget {
  final String groupID;
  final sdkInstance = TIMUIKitCore.getSDKInstance();
  final coreInstance = TIMUIKitCore.getInstance();

  GroupProfilePage({Key? key, required this.groupID}) : super(key: key);

  String _groupTypeText(String? type) {
    switch (type) {
      case "AVChatRoom":
        return TIM_t("聊天室");
      case "Meeting":
        return TIM_t("会议群");
      case "Public":
        return TIM_t("公开群");
      case "Work":
        return TIM_t("工作群");
      case "Community":
        return TIM_t("社群");
      default:
        return TIM_t("未知群");
    }
  }

  String _addOptText(int type) {
    switch (type) {
      case 0:
        return TIM_t("禁止加入");
      case 1:
        return TIM_t("需要审核");
      case 2:
        return TIM_t("自动通过");
      default:
        return "";
    }
  }

  String _getMemberShowName(V2TimGroupMemberFullInfo? item) {
    final friendRemark = item?.friendRemark ?? "";
    final nickName = item?.nickName ?? "";
    final userID = item?.userID ?? "";
    final showName = nickName != "" ? nickName : userID;
    return friendRemark != "" ? friendRemark : showName;
  }

  @override
  Widget build(BuildContext context) {
    final TUISelfInfoViewModel _selfInfoViewModel =
        serviceLocator<TUISelfInfoViewModel>();
    final TUIFriendShipViewModel _friendShipViewModel =
        serviceLocator<TUIFriendShipViewModel>();
    final theme = Provider.of<DefaultThemeData>(context).theme;

    final lifeCycle = GroupProfileLifeCycle(didLeaveGroup: () async {
      if (PlatformUtils().isWeb) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).popUntil(ModalRoute.withName("/homePage"));
      }
    });

    void _handleMemberTap(V2TimGroupMemberFullInfo memberInfo) {
      if (memberInfo.userID != _selfInfoViewModel.loginInfo?.userID) {
        _friendShipViewModel.isFriend(memberInfo.userID).then((isFriend) {
          if (!isFriend) {
            final V2TimUserFullInfo friendInfo = V2TimUserFullInfo(
                userID: memberInfo.userID,
                nickName: memberInfo.nickName,
                faceUrl: memberInfo.faceUrl);
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => SendApplication(
                        friendInfo: friendInfo, model: _selfInfoViewModel)));
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfile(userID: memberInfo.userID),
                ));
          }
        });
      }
    }

    void _showAddOptSheet(
        BuildContext ctx, int currentType, Function(int) handleActionTap) {
      showCupertinoModalPopup(
          context: ctx,
          builder: (c) => CupertinoActionSheet(
                actions: [0, 1, 2]
                    .map((t) => CupertinoActionSheetAction(
                          onPressed: () {
                            Navigator.pop(c);
                            handleActionTap(t);
                          },
                          child: Text(_addOptText(t)),
                        ))
                    .toList(),
                cancelButton: CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(c),
                    child: Text(TIM_t("取消"))),
              ));
    }

    void _showNameCardInput(BuildContext ctx, String nameCard,
        Function(String) setNameCard) {
      final ctrl = TextEditingController(text: nameCard);
      showDialog(
          context: ctx,
          builder: (c) => AlertDialog(
                title: Text(TIM_t("设置群昵称")),
                content: TextField(controller: ctrl),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(TIM_t("取消"))),
                  TextButton(
                      onPressed: () {
                        setNameCard(ctrl.text);
                        Navigator.pop(c);
                      },
                      child: Text(TIM_t("确定"))),
                ],
              ));
    }

    Widget _buildGroupOpRow(
        String label, String id, V2TimGroupInfo groupInfo) {
      return InkWell(
        onTap: () {
          if (id == "clearHistory") {
            showCupertinoModalPopup(
                context: context,
                builder: (c) => CupertinoActionSheet(
                      actions: [
                        CupertinoActionSheetAction(
                            onPressed: () async {
                              Navigator.pop(c);
                              if (PlatformUtils().isWeb) {
                                await sdkInstance
                                    .getConversationManager()
                                    .deleteConversation(
                                        conversationID: "group_${groupInfo.groupID}");
                              } else {
                                await sdkInstance
                                    .getMessageManager()
                                    .clearGroupHistoryMessage(
                                        groupID: groupInfo.groupID);
                              }
                            },
                            child: Text(TIM_t("确定"),
                                style: TextStyle(color: theme.cautionColor)))
                      ],
                      cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(c),
                          child: Text(TIM_t("取消"))),
                    ));
          } else if (id == "quitGroup") {
            showCupertinoModalPopup(
                context: context,
                builder: (c) => CupertinoActionSheet(
                      title: Text(TIM_t("退出后不会接收到此群聊消息")),
                      actions: [
                        CupertinoActionSheetAction(
                            onPressed: () async {
                              Navigator.pop(c);
                              final res = await sdkInstance.quitGroup(
                                  groupID: groupInfo.groupID);
                              if (res.code == 0) {
                                await sdkInstance
                                    .getConversationManager()
                                    .deleteConversation(
                                        conversationID:
                                            "group_${groupInfo.groupID}");
                                lifeCycle.didLeaveGroup();
                              }
                            },
                            child: Text(TIM_t("确定"),
                                style: TextStyle(color: theme.cautionColor)))
                      ],
                      cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(c),
                          child: Text(TIM_t("取消"))),
                    ));
          } else if (id == "dismissGroup") {
            showCupertinoModalPopup(
                context: context,
                builder: (c) => CupertinoActionSheet(
                      title: Text(TIM_t("解散后不会接收到此群聊消息")),
                      actions: [
                        CupertinoActionSheetAction(
                            onPressed: () async {
                              Navigator.pop(c);
                              final res = await sdkInstance.dismissGroup(
                                  groupID: groupInfo.groupID);
                              if (res.code == 0) {
                                await sdkInstance
                                    .getConversationManager()
                                    .deleteConversation(
                                        conversationID:
                                            "group_${groupInfo.groupID}");
                                lifeCycle.didLeaveGroup();
                              }
                            },
                            child: Text(TIM_t("确定"),
                                style: TextStyle(color: theme.cautionColor)))
                      ],
                      cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(c),
                          child: Text(TIM_t("取消"))),
                    ));
          }
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
              color: theme.weakBackgroundColor,
              border: Border(
                  bottom: BorderSide(
                      color: theme.weakDividerColor ??
                          CommonColor.weakDividerColor))),
          child: Text(label,
              style: TextStyle(color: theme.cautionColor, fontSize: 17)),
        ),
      );
    }

    return TencentPage(
        child: Scaffold(
            appBar: AppBar(
                title: Text(
                  TIM_t("群聊"),
                  style: TextStyle(
                      color: theme.darkTextColor ?? hexToColor("1f2329"),
                      fontSize: 16),
                ),
                shadowColor: theme.weakDividerColor,
                backgroundColor: theme.weakBackgroundColor,
                leading: IconButton(
                  padding: const EdgeInsets.only(left: 16),
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: theme.darkTextColor ?? hexToColor("2a2e35"),
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                )),
            body: SafeArea(
              child: TIMUIKitGroupProfile(
                lifeCycle: lifeCycle,
                groupID: groupID,
                onClickUser: (V2TimGroupMemberFullInfo memberInfo, _) {
                  if (memberInfo.userID !=
                      _selfInfoViewModel.loginInfo?.userID) {
                    _friendShipViewModel
                        .isFriend(memberInfo.userID)
                        .then((isFriend) {
                      if (!isFriend) {
                        V2TimUserFullInfo friendInfo = V2TimUserFullInfo(
                            userID: memberInfo.userID,
                            nickName: memberInfo.nickName,
                            faceUrl: memberInfo.faceUrl);
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SendApplication(
                                    friendInfo: friendInfo,
                                    model: _selfInfoViewModel)));
                      } else {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  UserProfile(userID: memberInfo.userID),
                            ));
                      }
                    });
                  }
                },
                profileWidgetBuilder: GroupProfileWidgetBuilder(
                  detailCard: (groupInfo, updateGroupName) {
                    final showName = groupInfo.groupName ?? groupInfo.groupID;
                    return Container(
                      color: theme.weakBackgroundColor,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Avatar(
                              faceUrl: groupInfo.faceUrl ?? "",
                              showName: showName,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  showName,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: theme.darkTextColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "ID: ${groupInfo.groupID}",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: theme.weakTextColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  operationDivider: () => const ThemeProfileDivider(),
                  memberListTile: (memberList) {
                    final safeList = memberList
                        .where((e) => e != null)
                        .cast<V2TimGroupMemberFullInfo>()
                        .toList();
                    final count = safeList.length;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      color: theme.weakBackgroundColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              TIM_t_para("群成员({{option1}}人)",
                                  "群成员({{option1}}人)")(option1: count.toString()),
                              style: TextStyle(
                                  color: theme.darkTextColor, fontSize: 16),
                            ),
                          ),
                          Wrap(
                            spacing: 20,
                            runSpacing: 10,
                            children: safeList.take(8).map((element) {
                              final showName = _getMemberShowName(element);
                              return InkWell(
                                onTap: () => _handleMemberTap(element),
                                child: SizedBox(
                                  width: 60,
                                  height: 76,
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: Avatar(
                                          faceUrl: element.faceUrl ?? "",
                                          showName: showName,
                                          type: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        showName,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            overflow: TextOverflow.ellipsis,
                                            color: theme.weakTextColor,
                                            fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                  searchMessage: () {
                    return TIMUIKitGroupProfileWidget.searchMessage(
                        (V2TimConversation? conversation) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => Search(
                                    onTapConversation: (V2TimConversation
                                                conversation,
                                            V2TimMessage? targetMsg) {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => Chat(
                                              selectedConversation: conversation,
                                              initFindingMsg: targetMsg,
                                            ),
                                          ));
                                    },
                                    conversation: conversation,
                                  )));
                    });
                  },
                  groupNotice: (currentNotice, toDefaultNoticeEditPage,
                          setGroupNotice) =>
                      ThemeOperationItem(
                        operationName: TIM_t("群公告"),
                        showArrow: true,
                        onTap: () => toDefaultNoticeEditPage(),
                      ),
                  groupManage: (toDefaultGroupManagementPage) =>
                      ThemeOperationItem(
                        operationName: TIM_t("群管理"),
                        showArrow: true,
                        onTap: () => toDefaultGroupManagementPage(),
                      ),
                  groupTypeBar: (groupType) => ThemeOperationItem(
                        operationName: TIM_t("群类型"),
                        operationRightWidget: Text(
                          _groupTypeText(groupType),
                          style: TextStyle(color: theme.weakTextColor),
                        ),
                        showArrow: false,
                      ),
                  groupJoiningModeBar:
                      (groupAddOptType, handleActionTap) => ThemeOperationItem(
                            operationName: TIM_t("加群方式"),
                            operationRightWidget: Text(
                              _addOptText(groupAddOptType),
                              style: TextStyle(color: theme.weakTextColor),
                            ),
                            showArrow: true,
                            onTap: () => _showAddOptSheet(
                                context, groupAddOptType, handleActionTap),
                          ),
                  nameCardBar: (nameCard, setNameCard) => ThemeOperationItem(
                        operationName: TIM_t("我的群昵称"),
                        operationRightWidget: Text(
                          nameCard,
                          style: TextStyle(color: theme.weakTextColor),
                        ),
                        showArrow: true,
                        onTap: () =>
                            _showNameCardInput(context, nameCard, setNameCard),
                      ),
                  muteGroupMessageBar: (isMute, setMute) => ThemeOperationItem(
                        operationName: TIM_t("消息免打扰"),
                        type: "switch",
                        operationValue: isMute,
                        onSwitchChange: (v) => setMute(v),
                      ),
                  pinedConversationBar:
                      (isPined, pinedConversation) => ThemeOperationItem(
                            operationName: TIM_t("置顶聊天"),
                            type: "switch",
                            operationValue: isPined,
                            onSwitchChange: (v) => pinedConversation(v),
                          ),
                  buttonArea: (groupInfo, groupMemberList) {
                    final isOwner =
                        groupInfo.owner == coreInstance.loginUserInfo?.userID;
                    final groupType = groupInfo.groupType ?? "";
                    final ops = <Map<String, dynamic>>[];
                    ops.add({"label": TIM_t("清空消息"), "id": "clearHistory"});
                    if (!isOwner) {
                      ops.add({"label": TIM_t("退出群组"), "id": "quitGroup"});
                    } else if (groupType != "Work") {
                      ops.add({"label": TIM_t("解散群组"), "id": "dismissGroup"});
                    }
                    return Container(
                      color: theme.weakBackgroundColor,
                      child: Column(
                        children: ops
                            .map((e) => _buildGroupOpRow(
                                e["label"] as String,
                                e["id"] as String,
                                groupInfo))
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
            )),
        name: 'groupProfile');
  }
}
