// ignore_for_file: file_names

import 'package:tencent_cloud_chat_demo/utils/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/theme_profile_widgets.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class NewContact extends StatefulWidget {
  const NewContact({Key? key}) : super(key: key);

  @override
  State<NewContact> createState() => _NewContactState();
}

class _NewContactState extends State<NewContact> {
  final TUIFriendShipViewModel _model =
      serviceLocator<TUIFriendShipViewModel>();

  @override
  void initState() {
    super.initState();
    _model.loadContactApplicationData();
  }

  Future<void> _handleApplication(
      V2TimFriendApplication app, bool accept) async {
    if (accept) {
      await _model.acceptFriendApplication(app.userID, app.type);
    } else {
      await _model.refuseFriendApplication(app.userID, app.type);
    }
    await _model.loadContactApplicationData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;

    Widget newContactWidget() {
      return ChangeNotifierProvider.value(
        value: _model,
        child: Consumer<TUIFriendShipViewModel>(
          builder: (context, model, _) {
            final apps = model.friendApplicationList
                    ?.where((e) => e != null)
                    .cast<V2TimFriendApplication>()
                    .toList() ??
                [];
            if (apps.isEmpty) {
              return Center(
                child: Text(TIM_t("暂无新联系人"),
                    style: TextStyle(color: theme.weakTextColor)),
              );
            }
            final isWideScreen =
                TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
            return ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                final showName = app.nickname ?? app.userID;
                return ThemeListItem(
                  showName: showName,
                  faceUrl: app.faceUrl,
                  subtitle: app.addWording,
                  onTap: isWideScreen
                      ? null
                      : () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserProfile(userID: app.userID),
                              ));
                        },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _handleApplication(app, true),
                        child: Text(TIM_t("同意"),
                            style: TextStyle(
                                color: theme.primaryColor, fontSize: 14)),
                      ),
                      TextButton(
                        onPressed: () => _handleApplication(app, false),
                        child: Text(TIM_t("拒绝"),
                            style: TextStyle(
                                color: theme.cautionColor, fontSize: 14)),
                      ),
                    ],
                  ),
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
            AppBackBar(title: TIM_t("新的联系人")),
            Expanded(child: newContactWidget()),
          ],
        ),
        defaultWidget: Scaffold(
          appBar: AppBar(
              title: Text(
                TIM_t("新的联系人"),
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
          body: newContactWidget(),
        ));
  }
}
