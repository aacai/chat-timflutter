import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/about_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/contact_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/settings.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/app_navigation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:url_launcher/url_launcher.dart';

class UserAvatar extends StatefulWidget {
  const UserAvatar({Key? key, required this.onChangeIndex}) : super(key: key);
  final ValueChanged<int> onChangeIndex;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  @override
  Widget build(BuildContext context) {
    final loginUserInfoModel = Provider.of<LoginUserInfo>(context);
    final V2TimUserFullInfo loginUserInfo = loginUserInfoModel.loginUserInfo;
    final theme = Provider.of<DefaultThemeData>(context).theme;

    return Column(
      children: [
        GestureDetector(
          onTapDown: (details) {
            TUIKitWidePopup.showPopupWindow(
              isDarkBackground: false,
              theme: theme,
              operationKey: TUIKitWideModalOperationKey.secondaryClickUserAvatar,
              context: context,
              offset: Offset(
                  details.globalPosition.dx + 10, details.globalPosition.dy - 200),
              child: (closeFunc) => AppMenu(
                items: [
                  AppMenuItem(
                    label: TIM_t("个人中心"),
                    icon: Icons.person_outline,
                    onTap: () {
                      widget.onChangeIndex(2);
                      closeFunc();
                    },
                  ),
                  AppMenuItem(
                    label: TIM_t("关于我们"),
                    icon: Icons.info_outline,
                    onTap: () {
                      closeFunc();
                      TUIKitWidePopup.showPopupWindow(
                        operationKey: TUIKitWideModalOperationKey.aboutUs,
                        context: context,
                        theme: theme,
                        title: TIM_t("关于我们"),
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: (closeFunc) => AboutUs(closeFunc: closeFunc),
                      );
                    },
                  ),
                  AppMenuItem(
                    label: TIM_t("联系我们"),
                    icon: Icons.mail_outline,
                    onTap: () {
                      closeFunc();
                      TUIKitWidePopup.showPopupWindow(
                        operationKey: TUIKitWideModalOperationKey.contactUs,
                        context: context,
                        theme: theme,
                        title: TIM_t("联系我们"),
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: (closeFunc) => ContactUs(closeFunc: closeFunc),
                      );
                    },
                  ),
                  AppMenuItem(
                    label: TIM_t("设置"),
                    icon: Icons.settings_outlined,
                    onTap: () {
                      closeFunc();
                      TUIKitWidePopup.showPopupWindow(
                        operationKey: TUIKitWideModalOperationKey.settings,
                        context: context,
                        theme: theme,
                        title: TIM_t("设置"),
                        width: MediaQuery.of(context).size.width * 0.7,
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: (closeFunc) => Settings(closeFunc: closeFunc),
                      );
                    },
                  ),
                  AppMenuItem(
                    label: TIM_t("意见反馈"),
                    icon: Icons.feedback_outlined,
                    onTap: () {
                      closeFunc();
                      launchUrl(
                        Uri.parse("https://wj.qq.com/s2/11858997/6b56/"),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 20, top: 40),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Avatar(
                    faceUrl: loginUserInfo.faceUrl ?? "",
                    showName: loginUserInfo.nickName ?? ""),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
