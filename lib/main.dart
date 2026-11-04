// ignore_for_file: unused_import, deprecated_member_use

import 'dart:io' show Platform;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:desktop_webview_window_for_is/desktop_webview_window_for_is.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_cloud_chat_demo/custom_animation.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/pages/app.dart';
import 'package:tencent_cloud_chat_demo/src/provider/custom_sticker_package.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_guide_provider.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_demo/utils/app_navigation.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

void main(List<String> args) {
  debugPrint('args: $args');
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  // 首帧之前状态栏不能是浅色，否则深色模式下启动瞬间会亮一下。
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  // 全局loading
  configLoading();
  // AutoSizeUtil.setStandard(375, isAutoTextSize: true);
  // fast i18n use device locale
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  if (PlatformUtils().isAndroid) {
    SystemUiOverlayStyle systemUiOverlayStyle = const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    );
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }

  // 方向锁是异步平台调用，不能用它的 Future 包住 runApp：
  // 桌面端该调用可能迟迟不返回，Flutter 首帧一直不出，窗口就停在原生白底上。
  if (!PlatformUtils().isDesktop) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  runApp(
    TranslationProvider(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LoginUserInfo()),
          ChangeNotifierProvider(create: (_) => DefaultThemeData()),
          ChangeNotifierProvider(create: (_) => CustomStickerPackageData()),
          ChangeNotifierProvider(
            create: (_) => LocalSetting(),
          ),
          ChangeNotifierProvider(create: (_) => UserGuideProvider()),
        ],
        child: const TUIKitDemoApp(),
      ),
    ),
  );

  if (PlatformUtils().isDesktop) {
    doWhenWindowReady(() {
      const initialSize = Size(1300, 830);
      // 允许缩到小屏宽度，窗口变窄时 ResponsiveHome 会自动切移动布局；
      // 原来的 1100 下限会把宽屏布局锁死，无法验证小屏适配。
      appWindow.minSize = const Size(360, 560);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }

  // );
}

class TUIKitDemoApp extends StatelessWidget {
  const TUIKitDemoApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final themeData = Provider.of<DefaultThemeData>(context);
    final currentType = themeData.currentThemeType;
    final light = DefTheme.getTheme(currentType, DarkModeType.light);
    final dark = DefTheme.getTheme(currentType, DarkModeType.dark);
    final isDark = themeData.themeMode == ThemeMode.dark ||
        (themeData.themeMode == ThemeMode.system && DefTheme.isPlatformDark);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: MaterialApp(
        title: '可达',
        debugShowCheckedModeBanner: false,
        // 首帧渲染前引擎用来填充窗口的底色，跟随明暗主题，避免启动闪白。
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        locale: TranslationProvider.of(context).flutterLocale, // use provider
        supportedLocales: LocaleSettings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        themeMode: themeData.themeMode,
        theme: ThemeData(
          platform: TargetPlatform.iOS,
          brightness: Brightness.light,
          scaffoldBackgroundColor: light.weakBackgroundColor,
          canvasColor: light.weakBackgroundColor,
          colorScheme: ColorScheme.light(
            surface: AppColors.lightSurface,
            primary: light.primaryColor ?? AppColors.onPrimary,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.lightSurface,
            surfaceTintColor: Colors.transparent,
          ),
          pageTransitionsTheme: PageTransitionsTheme(builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
            backgroundColor: light.primaryColor,
          )),
        ),
        darkTheme: ThemeData(
          platform: TargetPlatform.iOS,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: dark.weakBackgroundColor,
          canvasColor: dark.weakBackgroundColor,
          colorScheme: ColorScheme.dark(
            surface: AppColors.darkSurface,
            primary: dark.primaryColor ?? AppColors.onPrimary,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.darkSurface,
            surfaceTintColor: Colors.transparent,
          ),
          // CupertinoAlertDialog（登录页隐私协议）也要跟随夜间模式
          cupertinoOverrideTheme: const CupertinoThemeData(
            brightness: Brightness.dark,
          ),
          pageTransitionsTheme: PageTransitionsTheme(builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
            backgroundColor: dark.primaryColor,
          )),
        ),
        home: const TencentChatApp(),
        navigatorKey: InitStep.navigatorKey,
        builder: (context, child) => AppEscapeScope(
          child: EasyLoading.init()(context, child) ?? const SizedBox.shrink(),
        ),
        navigatorObservers: !PlatformUtils().isMobile ? [] : [TUICallKit.navigatorObserver],
      ),
    );
  }
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.yellow
    ..backgroundColor = Colors.green
    ..indicatorColor = Colors.yellow
    ..textColor = Colors.yellow
    ..maskColor = Colors.blue.withOpacity(0.5)
    ..userInteractions = true
    ..dismissOnTap = false
    ..customAnimation = CustomAnimation();
}
