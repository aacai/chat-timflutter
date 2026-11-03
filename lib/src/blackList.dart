// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';

import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/theme_profile_widgets.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class BlackList extends StatefulWidget {
  const BlackList({Key? key}) : super(key: key);

  @override
  State<BlackList> createState() => _BlackListState();
}

class _BlackListState extends State<BlackList> {
  final TUIFriendShipViewModel _model =
      serviceLocator<TUIFriendShipViewModel>();

  @override
  void initState() {
    super.initState();
    _model.loadBlockListData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;

    Widget blockedUsers() {
      return ChangeNotifierProvider.value(
        value: _model,
        child: Consumer<TUIFriendShipViewModel>(
          builder: (context, model, _) {
            final list = model.blockList;
            if (list.isEmpty) {
              return Center(
                child: Text(TIM_t("暂无黑名单"),
                    style: TextStyle(color: theme.weakTextColor)),
              );
            }
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final info = list[index];
                final nickName = info.userProfile?.nickName ?? "";
                final showName = (info.friendRemark?.isNotEmpty == true)
                    ? info.friendRemark!
                    : (nickName.isNotEmpty ? nickName : info.userID);
                return ThemeListItem(
                  showName: showName,
                  faceUrl: info.userProfile?.faceUrl,
                  onTap: () {
                    final isWideScreen =
                        TUIKitScreenUtils.getFormFactor(context) ==
                            DeviceType.Desktop;
                    if (!isWideScreen) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UserProfile(userID: info.userID),
                          ));
                    }
                  },
                );
              },
            );
          },
        ),
      );
    }

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: blockedUsers(),
        defaultWidget: Scaffold(
          appBar: AppBar(
              title: Text(
                TIM_t("黑名单"),
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
              shadowColor: Colors.white,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.lightPrimaryColor ?? CommonColor.lightPrimaryColor,
                    theme.primaryColor ?? CommonColor.primaryColor
                  ]),
                ),
              ),
              iconTheme: const IconThemeData(
                color: Colors.white,
              )),
          body: blockedUsers(),
        ));
  }
}
