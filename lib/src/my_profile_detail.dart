import 'dart:math';

import 'package:adaptive_action_sheet/adaptive_action_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/about_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/contact_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/settings.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/routes.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/theme_profile_widgets.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/app_navigation.dart';
import 'package:tencent_cloud_chat_demo/utils/auto_login_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

import 'avatar_select_page.dart';

class MyProfileDetail extends StatefulWidget {
  final V2TimUserFullInfo? userProfile;
  final TIMUIKitProfileController? controller;

  const MyProfileDetail({Key? key, this.userProfile, this.controller})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => MyProfileDetailState();
}

class MyProfileDetailState extends State<MyProfileDetail> {
  final CoreServicesImpl _coreServices = TIMUIKitCore.getInstance();
  late V2TimUserFullInfo? userProfile;
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    userProfile = widget.userProfile;
    if (userProfile?.birthday != null && userProfile?.birthday != 0) {
      final date = DateTime.parse(userProfile!.birthday.toString());
      selectedDate = date;
    } else {
      selectedDate = DateTime.now();
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final res = await _coreServices.logout();
    if (res.code == 0) {
      await AutoLoginStore.clearAll();
      Routes().directToLoginPage();
    }
  }

  void showGenderChoseSheet(BuildContext context, TUITheme? theme) {
    showAdaptiveActionSheet(
      context: context,
      title: Text(TIM_t("性别")),
      actions: <BottomSheetAction>[
        BottomSheetAction(
          title: Text(TIM_t("男"), style: TextStyle(color: theme?.primaryColor)),
          onPressed: (_) => _setGender(1, () => Navigator.pop(context)),
        ),
        BottomSheetAction(
          title: Text(TIM_t("女"), style: TextStyle(color: theme?.primaryColor)),
          onPressed: (_) => _setGender(2, () => Navigator.pop(context)),
        ),
      ],
      cancelAction: CancelAction(title: Text(TIM_t("取消"))),
    );
  }

  Future<void> _setGender(int gender, VoidCallback close) async {
    close();
    final res = await widget.controller?.updateGender(gender);
    if (res?.code == 0 && mounted) {
      setState(() => userProfile?.gender = gender);
    }
  }

  Future<void> showSelectAvatarPage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarSelectPage(
            controller: widget.controller,
            selectedAvatarUrl: userProfile?.faceUrl ?? ""),
      ),
    );
    if (result != null && mounted) {
      setState(() => userProfile?.faceUrl = result as String);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && pickedDate != selectedDate) {
      final birthdayString = pickedDate.year.toString() +
          TimeAgo.getMonth(pickedDate) +
          TimeAgo.getDay(pickedDate);
      final result =
          await widget.controller?.updateBirthday(int.parse(birthdayString));
      if (result?.code == 0 && mounted) {
        setState(() => selectedDate = pickedDate);
      }
    }
  }

  String _birthdayText() {
    final birthday = userProfile?.birthday;
    if (birthday == null || birthday == 0) {
      return TIM_t("未填写");
    }
    final str = birthday.toString();
    if (str.length == 8) {
      return "${str.substring(0, 4)}-${str.substring(4, 6)}-${str.substring(6, 8)}";
    }
    return str;
  }

  Offset _inputOffset(TapDownDetails details) {
    final size = MediaQuery.of(context).size;
    return Offset(
      min(details.globalPosition.dx, size.width - 400),
      min(details.globalPosition.dy, size.height - 100),
    );
  }

  void _editNickName(TapDownDetails details, TUITheme theme) {
    widget.controller?.showTextInputBottomSheet(
      context: context,
      title: TIM_t("修改昵称"),
      tips: TIM_t("仅限汉字、英文、数字和下划线"),
      initOffset: _inputOffset(details),
      onSubmitted: (String nickName) async {
        final res = await widget.controller?.updateNickName(nickName);
        if (res?.code == 0 && mounted) {
          setState(() => userProfile?.nickName = nickName);
        }
      },
      theme: theme,
    );
  }

  void _editSignature(TapDownDetails details, TUITheme theme) {
    widget.controller?.showTextInputBottomSheet(
      context: context,
      title: TIM_t("修改签名"),
      tips: TIM_t("仅限汉字、英文、数字和下划线"),
      initOffset: _inputOffset(details),
      onSubmitted: (String selfSignature) async {
        final res =
            await widget.controller?.updateSelfSignature(selfSignature);
        if (res?.code == 0 && mounted) {
          setState(() => userProfile?.selfSignature = selfSignature);
        }
      },
      theme: theme,
    );
  }

  void _pickGender(TapDownDetails details, TUITheme theme) {
    if (TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop) {
      TUIKitWidePopup.showPopupWindow(
        isDarkBackground: false,
        operationKey: TUIKitWideModalOperationKey.secondaryClickUserAvatar,
        context: context,
        offset: Offset(details.globalPosition.dx, details.globalPosition.dy),
        child: (closeFunc) => AppMenu(
          items: [
            AppMenuItem(
                label: TIM_t("男"),
                icon: Icons.male,
                onTap: () => _setGender(1, closeFunc)),
            AppMenuItem(
                label: TIM_t("女"),
                icon: Icons.female,
                onTap: () => _setGender(2, closeFunc)),
          ],
        ),
      );
    } else {
      showGenderChoseSheet(context, theme);
    }
  }

  void _openPopup(
    String title,
    TUIKitWideModalOperationKey key,
    double ratio,
    Widget Function(VoidCallback close) builder,
    TUITheme theme,
  ) {
    final size = MediaQuery.of(context).size;
    TUIKitWidePopup.showPopupWindow(
      operationKey: key,
      context: context,
      theme: theme,
      title: title,
      width: size.width * ratio,
      height: size.height * ratio,
      child: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final surface = AppColors.surfaceOf(context);
    final onSurface = AppColors.onSurfaceOf(context);
    final nickName = userProfile?.nickName ?? "";
    final signature = userProfile?.selfSignature ?? "";
    final userID = userProfile?.userID ?? "";
    final gender = userProfile?.gender ?? 0;
    final hasBirthday = (userProfile?.birthday ?? 0) != 0;

    return Scaffold(
      backgroundColor: surface,
      appBar: isWideScreen
          ? null
          : AppBar(
              iconTheme: IconThemeData(color: onSurface),
              backgroundColor: surface,
              foregroundColor: onSurface,
              elevation: 0,
              scrolledUnderElevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0.5),
                child: Container(
                    height: 0.5, color: AppColors.dividerOf(context)),
              ),
              title: Text(
                TIM_t("个人资料"),
                style: TextStyle(
                    fontSize: IMDemoConfig.appBarTitleFontSize,
                    fontWeight: FontWeight.w600,
                    color: onSurface),
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWideScreen) AppBackBar(title: TIM_t("个人资料")),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileHeader(
                        userInfo: userProfile,
                        onClickAvatar: () => showSelectAvatarPage(context),
                      ),
                      ProfileSection(
                        title: TIM_t("基本信息"),
                        rows: [
                          ProfileRow(
                            label: TIM_t("昵称"),
                            value: nickName.isNotEmpty
                                ? nickName
                                : TIM_t("未填写"),
                            valueMuted: nickName.isEmpty,
                            onTapDown: (d) => _editNickName(d, theme),
                          ),
                          ProfileRow(
                            label: TIM_t("账号"),
                            showArrow: false,
                            valueWidget: SelectableText(
                              userID,
                              maxLines: 1,
                              textAlign: TextAlign.end,
                              style:
                                  TextStyle(fontSize: 14, color: onSurface),
                            ),
                          ),
                          ProfileRow(
                            label: TIM_t("个性签名"),
                            value: signature.isNotEmpty
                                ? signature
                                : TIM_t("未填写"),
                            valueMuted: signature.isEmpty,
                            onTapDown: (d) => _editSignature(d, theme),
                          ),
                          ProfileRow(
                            label: TIM_t("性别"),
                            value: gender == 1
                                ? TIM_t("男")
                                : (gender == 2 ? TIM_t("女") : TIM_t("未填写")),
                            valueMuted: gender != 1 && gender != 2,
                            onTapDown: (d) => _pickGender(d, theme),
                          ),
                          ProfileRow(
                            label: TIM_t("生日"),
                            value: _birthdayText(),
                            valueMuted: !hasBirthday,
                            onTap: () => _selectDate(context),
                          ),
                        ],
                      ),
                      if (isWideScreen)
                        ProfileSection(
                          title: TIM_t("更多"),
                          rows: [
                            ProfileRow(
                              label: TIM_t("设置"),
                              onTap: () => _openPopup(
                                  TIM_t("设置"),
                                  TUIKitWideModalOperationKey.settings,
                                  0.7,
                                  (close) => Settings(closeFunc: close),
                                  theme),
                            ),
                            ProfileRow(
                              label: TIM_t("联系我们"),
                              onTap: () => _openPopup(
                                  TIM_t("联系我们"),
                                  TUIKitWideModalOperationKey.contactUs,
                                  0.6,
                                  (close) => ContactUs(closeFunc: close),
                                  theme),
                            ),
                            ProfileRow(
                              label: TIM_t("关于"),
                              onTap: () => _openPopup(
                                  TIM_t("关于我们"),
                                  TUIKitWideModalOperationKey.aboutUs,
                                  0.6,
                                  (close) => AboutUs(closeFunc: close),
                                  theme),
                            ),
                          ],
                        ),
                      ProfileSection(
                        rows: [
                          ProfileRow(
                            label: TIM_t("退出登录"),
                            danger: true,
                            showArrow: false,
                            onTap: () => _handleLogout(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
