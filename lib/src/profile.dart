// ignore_for_file: unused_import

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/about.dart';
import 'package:tencent_cloud_chat_demo/src/avatar_select_page.dart';
import 'package:tencent_cloud_chat_demo/src/my_profile_detail.dart';
import 'package:tencent_cloud_chat_demo/src/pages/skin/skin_page.dart';
import 'package:tencent_cloud_chat_demo/utils/app_navigation.dart';
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
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/theme_profile_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/routes.dart';
import 'package:tencent_cloud_chat_demo/utils/file_transfer/file_transfer_service.dart';
import 'package:tencent_cloud_chat_demo/utils/secure_channel/encryption_service.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

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

  Future<void> _changeAvatar(V2TimUserFullInfo? userProfile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarSelectPage(
            controller: _timuiKitProfileController,
            selectedAvatarUrl: userProfile?.faceUrl ?? ""),
      ),
    );
  }

  _handleLogout() async {
    final res = await _coreServices.logout();
    if (res.code == 0) {
      await AutoLoginStore.clearAll();
      EncryptionService.instance.clearPeerCache();
      Routes().directToLoginPage();
    }
  }

  Future<void> _showChunkSizeSheet(LocalSetting localSetting, theme) async {
    final picked = await showProfilePickerDialog<int>(
      context: context,
      title: TIM_t("大文件分片大小"),
      selected: localSetting.chunkSizeMB,
      accent: theme.primaryColor,
      options: chunkSizePresetsMB
          .map((mb) => ProfileOption(value: mb, label: "$mb MB"))
          .toList(),
    );
    if (picked == null) return;
    localSetting.chunkSizeMB = picked;
    FileTransferService.instance.chunkSizeBytes = picked * 1024 * 1024;
  }

  Future<void> _showDarkModeSheet(DefaultThemeData themeData) async {
    final picked = await showProfilePickerDialog<DarkModeType>(
      context: context,
      title: TIM_t("夜间模式"),
      selected: themeData.darkMode,
      accent: themeData.theme.primaryColor,
      options: DarkModeType.values
          .map((mode) => ProfileOption(value: mode, label: mode.label))
          .toList(),
    );
    if (picked != null) {
      themeData.darkMode = picked;
    }
  }

  changeFriendVerificationMethod(int allowType) async {
    _timuiKitProfileController.changeFriendVerificationMethod(allowType);
  }

  Future<void> showApplicationTypeSheet(theme) async {
    final picked = await showProfilePickerDialog<int>(
      context: context,
      title: TIM_t("加我为好友的方式"),
      accent: theme.primaryColor,
      options: [
        ProfileOption(value: 0, label: TIM_t("允许任何人")),
        ProfileOption(value: 1, label: TIM_t("需要验证信息")),
        ProfileOption(value: 2, label: TIM_t("禁止加我为好友")),
      ],
    );
    if (picked != null) {
      changeFriendVerificationMethod(picked);
    }
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
                  ProfileHeader(
                    userInfo: userProfile,
                    showArrowRightIcon: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyProfileDetail(
                            userProfile: userProfile,
                            controller: _timuiKitProfileController),
                      ),
                    ),
                    onChangeAvatar: () => _changeAvatar(userProfile),
                  ),
                  ProfileSection(
                    title: TIM_t("偏好设置"),
                    rows: [
                      ProfileRow(
                        icon: Icons.person_add_outlined,
                        label: TIM_t("加我为好友的方式"),
                        value: allowText,
                        onTap: () => showApplicationTypeSheet(theme),
                      ),
                      ProfileRow(
                        icon: Icons.palette_outlined,
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
                        icon: Icons.dark_mode_outlined,
                        label: TIM_t("夜间模式"),
                        value: themeData.darkMode.label,
                        onTap: () => _showDarkModeSheet(themeData),
                      ),
                      ProfileRow(
                        icon: Icons.storage_outlined,
                        label: TIM_t("大文件分片大小"),
                        value: "${localSetting.chunkSizeMB} MB",
                        onTap: () => _showChunkSizeSheet(localSetting, theme),
                      ),
                    ],
                  ),
                  ProfileSection(
                    title: TIM_t("消息与联系人"),
                    rows: [
                      ProfileRow(
                        icon: Icons.mark_chat_read_outlined,
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
                        icon: Icons.visibility_outlined,
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
                        icon: Icons.info_outline,
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
