import 'package:tencent_cloud_chat_demo/utils/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_demo/src/chat.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/theme_profile_widgets.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class GroupList extends StatefulWidget {
  final void Function(V2TimGroupInfo groupInfo, V2TimConversation conversation)?
      onTapItem;

  const GroupList({Key? key, this.onTapItem}) : super(key: key);

  @override
  State<GroupList> createState() => _GroupListState();
}

class _GroupListState extends State<GroupList> {
  final TUIFriendShipViewModel _model =
      serviceLocator<TUIFriendShipViewModel>();

  @override
  void initState() {
    super.initState();
    _model.loadGroupListData();
  }

  Future<void> _jumpToChatPage(
      BuildContext context, V2TimGroupInfo groupInfo) async {
    final res = await TIMUIKitCore.getSDKInstance()
        .getConversationManager()
        .getConversation(conversationID: "group_${groupInfo.groupID}");
    if (res.code != 0 || res.data == null) {
      return;
    }
    final conversation = res.data!;
    if (widget.onTapItem != null) {
      widget.onTapItem!(groupInfo, conversation);
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Chat(selectedConversation: conversation),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;

    Widget groupList() {
      return ChangeNotifierProvider.value(
        value: _model,
        child: Consumer<TUIFriendShipViewModel>(
          builder: (context, model, _) {
            final list = model.groupList
                .where((g) => !g.groupID.contains("im_discuss_"))
                .toList();
            if (list.isEmpty) {
              return Center(
                child: Text(TIM_t("暂无群聊"),
                    style: TextStyle(color: theme.weakTextColor)),
              );
            }
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final groupInfo = list[index];
                final showName = groupInfo.groupName ?? groupInfo.groupID;
                return ThemeListItem(
                  showName: showName,
                  faceUrl: groupInfo.faceUrl,
                  onTap: () => _jumpToChatPage(context, groupInfo),
                );
              },
            );
          },
        ),
      );
    }

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBackBar(title: TIM_t("群聊")),
            Expanded(child: groupList()),
          ],
        ),
        defaultWidget: Scaffold(
          appBar: AppBar(
              title: Text(
                TIM_t("群聊"),
                style: const TextStyle(color: AppColors.onPrimary, fontSize: 17),
              ),
              shadowColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.lightPrimaryColor ?? CommonColor.lightPrimaryColor,
                    theme.primaryColor ?? CommonColor.primaryColor
                  ]),
                ),
              ),
              iconTheme: const IconThemeData(
                color: AppColors.onPrimary,
              )),
          body: groupList(),
        ));
  }
}
