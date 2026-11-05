// ignore_for_file: unused_import

import 'dart:math';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/about.dart';
import 'package:tencent_cloud_chat_demo/src/my_profile_detail.dart';
import 'package:tencent_cloud_chat_demo/src/pages/skin/skin_page.dart';
import 'package:tencent_cloud_chat_demo/utils/auto_login_store.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/pages/login.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/theme_profile_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/routes.dart';
import 'package:tencent_cloud_chat_demo/utils/file_transfer/file_transfer_service.dart';
import 'package:tencent_cloud_chat_demo/utils/secure_channel/encryption_service.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:adaptive_action_sheet/adaptive_action_sheet.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class MyProfile extends StatefulWidget {
  const MyProfile({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ProfileState();
}

class _ProfileState extends State<MyProfile> {
  final CoreServicesImpl _coreServices = TIMUIKitCore.getInstance();
  final V2TIMManager sdkInstance = TIMUIKitCore.getSDKInstance();
  final TIMUIKitProfileController _timuiKitProfileController =
      TIMUIKitProfileController();

  String _getAllowText(int? allowType) {
    if (allowType == 0) {
      return TIM_t("允许任何人");
    }
    if (allowType == 1) {
      return TIM_t("需要验证信息");
    }
    if (allowType == 2) {
      return TIM_t("禁止加我为好友");
    }
    return TIM_t("未指定");
  }

  _handleLogout() async {
    final res = await _coreServices.logout();
    if (res.code == 0) {
      await AutoLoginStore.clearAll();
      EncryptionService.instance.clearPeerCache();
      Routes().directToLoginPage();
    }
  }

  _showChunkSizeSheet(LocalSetting localSetting) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final current = localSetting.chunkSizeMB;
    showAdaptiveActionSheet(
      context: context,
      actions: chunkSizePresetsMB
          .map((mb) => BottomSheetAction(
                title: Text(
                  mb == current
                      ? TIM_t_para("{{mb}} MB ✓", "$mb MB ✓")(mb: mb)
                      : "$mb MB",
                  style: TextStyle(color: theme.primaryColor, fontSize: 18),
                ),
                onPressed: (_) {
                  localSetting.chunkSizeMB = mb;
                  FileTransferService.instance.chunkSizeBytes =
                      mb * 1024 * 1024;
                  Navigator.of(context, rootNavigator: true).pop();
                },
              ))
          .toList(),
      cancelAction: CancelAction(
        title: Text(TIM_t("取消"), style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  void _showDarkModeSheet(DefaultThemeData themeData) {
    showAdaptiveActionSheet(
      context: context,
      actions: DarkModeType.values
          .map((mode) => BottomSheetAction(
                title: Text(
                  mode == themeData.darkMode ? "${mode.label} ✓" : mode.label,
                  style: TextStyle(
                      color: themeData.theme.primaryColor, fontSize: 16),
                ),
                onPressed: (_) {
                  themeData.darkMode = mode;
                  Navigator.of(context, rootNavigator: true).pop();
                },
              ))
          .toList(),
      cancelAction: CancelAction(title: Text(TIM_t("取消"))),
    );
  }

  changeFriendVerificationMethod(int allowType) async {
    _timuiKitProfileController.changeFriendVerificationMethod(allowType);
  }

  showApplicationTypeSheet(theme) async {
    const allowAny = 0;
    const neddConfirm = 1;
    const denyAny = 2;

    showAdaptiveActionSheet(
      context: context,
      actions: <BottomSheetAction>[
        BottomSheetAction(
          title: Text(TIM_t("允许任何人"),
              style: TextStyle(color: theme.primaryColor, fontSize: 18)),
          onPressed: (_) {
            changeFriendVerificationMethod(allowAny);
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        BottomSheetAction(
          title: Text(TIM_t("需要验证信息"),
              style: TextStyle(color: theme.primaryColor, fontSize: 18)),
          onPressed: (_) {
            changeFriendVerificationMethod(neddConfirm);
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        BottomSheetAction(
          title: Text(TIM_t("禁止加我为好友"),
              style: TextStyle(color: theme.primaryColor, fontSize: 18)),
          onPressed: (_) {
            changeFriendVerificationMethod(denyAny);
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
      ],
      cancelAction: CancelAction(
        title: Text(TIM_t("取消"), style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LocalSetting localSetting = Provider.of<LocalSetting>(context);
    final themeData = Provider.of<DefaultThemeData>(context);
    final themeType = themeData.currentThemeType;
    final theme = themeData.theme;
    final loginUserInfoModel = Provider.of<LoginUserInfo>(context);
    final V2TimUserFullInfo loginUserInfo = loginUserInfoModel.loginUserInfo;
    return TIMUIKitProfile(
      isSelf: true,
      userID: loginUserInfo.userID ?? "",
      controller: _timuiKitProfileController,
      builder: (BuildContext context, V2TimFriendInfo userInfo,
          V2TimConversation conversation, int friendType, bool isMute) {
        final userProfile = userInfo.userProfile;
        final allowText = _getAllowText(userProfile?.allowType);
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyProfileDetail(
                            userProfile: userProfile,
                            controller: _timuiKitProfileController),
                      ),
                    ),
                    child: ProfileHeader(
                      userInfo: userProfile,
                      showArrowRightIcon: true,
                    ),
                  ),
                  ProfileSection(
                    title: TIM_t("偏好设置"),
                    rows: [
                      ProfileRow(
                        label: TIM_t("加我为好友的方式"),
                        value: allowText,
                        onTap: () => showApplicationTypeSheet(theme),
                      ),
                      ProfileRow(
                        label: TIM_t("更换皮肤"),
                        value: DefTheme.defaultThemeName[themeType]!,
                        valueColor: theme.primaryColor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SkinPage()),
                        ),
                      ),
                      ProfileRow(
                        label: TIM_t("夜间模式"),
                        value: themeData.darkMode.label,
                        onTap: () => _showDarkModeSheet(themeData),
                      ),
                      ProfileRow(
                        label: TIM_t("大文件分片大小"),
                        value: "${localSetting.chunkSizeMB} MB",
                        onTap: () => _showChunkSizeSheet(localSetting),
                      ),
                    ],
                  ),
                  ProfileSection(
                    title: TIM_t("消息与联系人"),
                    rows: [
                      ProfileRow(
                        label: TIM_t("消息阅读状态"),
                        description: TIM_t(
                            "关闭后，您收发的消息均不带消息阅读状态，您将无法看到对方是否已读，同时对方也无法看到你是否已读。"),
                        switchValue: localSetting.isShowReadingStatus,
                        onSwitchChanged: (bool value) {
                          localSetting.isShowReadingStatus = value;
                          if (value) {
                            ToastUtils.toast(TIM_t("该功能为旗舰版功能"));
                          }
                        },
                      ),
                      ProfileRow(
                        label: TIM_t("显示在线状态"),
                        description: TIM_t(
                            "关闭后，您将不可以在会话列表和通讯录中看到好友在线或离线的状态提示。"),
                        switchValue: localSetting.isShowOnlineStatus,
                        onSwitchChanged: (bool value) =>
                            localSetting.isShowOnlineStatus = value,
                      ),
                    ],
                  ),
                  ProfileSection(
                    title: TIM_t("关于"),
                    rows: [
                      ProfileRow(
                        label: TIM_t("关于腾讯云 · IM"),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const About()),
                        ),
                      ),
                    ],
                  ),
                  ProfileSection(
                    rows: [
                      ProfileRow(
                        label: TIM_t("退出登录"),
                        danger: true,
                        showArrow: false,
                        onTap: _handleLogout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
