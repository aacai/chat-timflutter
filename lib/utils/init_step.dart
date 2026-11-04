import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/home_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/home_page.dart';
import 'package:tencent_cloud_chat_demo/utils/app_navigation.dart';
import 'package:tencent_cloud_chat_demo/src/pages/login.dart';
import 'package:tencent_cloud_chat_demo/src/provider/custom_sticker_package.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/auto_login_store.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

/// 全应用唯一的 Navigator key。所有"切到登录页/主页"的跳转都走它，
/// 而不是依赖某个 Widget 的 BuildContext——后者在页面重建/销毁后容易变成过期的
/// context，往已 dispose 的 Navigator 里 push 就会抛
/// "A Routes was used after being disposed"。
class InitStep {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static setTheme(String themeTypeString, BuildContext context) {
    final CoreServicesImpl _coreInstance = TIMUIKitCore.getInstance();
    ThemeType themeType = DefTheme.themeTypeFromString(themeTypeString);
    Provider.of<DefaultThemeData>(context, listen: false).currentThemeType =
        themeType;
    _coreInstance.setTheme(theme: DefTheme.getTheme(themeType, Provider.of<DefaultThemeData>(context, listen: false).darkMode));
  }

  static setCustomSticker(BuildContext context) async {
    // 添加自定义表情包
    List<CustomStickerPackage> customStickerPackageList = [];

    customStickerPackageList.addAll(Const.emojiList.map((customEmojiPackage) {
      return CustomStickerPackage(
          name: customEmojiPackage.name,
          baseUrl: "assets/custom_face_resource/${customEmojiPackage.name}",
          isEmoji: customEmojiPackage.isEmoji,
          stickerList: customEmojiPackage.list
              .asMap()
              .keys
              .map((idx) =>
              CustomSticker(index: idx, name: customEmojiPackage.list[idx]))
              .toList(),
          menuItem: CustomSticker(
            index: 0,
            name: customEmojiPackage.icon,
          ));
    }).toList());

    Provider.of<CustomStickerPackageData>(context, listen: false)
        .customStickerPackageList = customStickerPackageList;
  }

  static removeLocalSetting() async {
    await AutoLoginStore.clearAll();
  }

  /// 启动分流：登录页自己决定要不要自动登录，这里只负责把界面切过去。
  static void checkLogin(BuildContext context, initIMSDKAndAddIMListeners) {
    initIMSDKAndAddIMListeners();

    Future.delayed(const Duration(seconds: 1), () {
      directToLogin(context);
      setCustomSticker(context);
    });
  }

  static void directToLogin(BuildContext context, [Function? initIMSDKAndAddIMListeners]) {
    _replace((navigator) {
      navigator.pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (BuildContext context, Animation<double> animation,
              Animation secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: LoginPage(initIMSDK: initIMSDKAndAddIMListeners),
            );
          },
        ),
      );
    });
  }

  static void directToHomePage(BuildContext context) {
    _replace((navigator) {
      navigator.pushReplacement(
        PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (BuildContext context, Animation<double> animation,
                Animation secondaryAnimation) {
              return FadeTransition(
                opacity: animation,
                child: const ResponsiveHome(),
              );
            },
            settings: const RouteSettings(name: '/homePage')),
      );
    });
  }

  /// 用全局 navigatorKey 做路由替换，避免依赖（可能过期的）BuildContext。
  static void _replace(void Function(NavigatorState navigator) action) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[InitStep] navigator 尚未就绪，跳过路由跳转');
      return;
    }
    action(navigator);
  }
}
