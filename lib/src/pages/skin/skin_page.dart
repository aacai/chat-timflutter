import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class SkinPage extends StatelessWidget {
  const SkinPage({Key? key}) : super(key: key);

  List<Widget> skinBuilder() => ThemeType.values
      .map((type) => SkinCube(
            currentThemeType: type,
          ))
      .toList();

  /// 夜间模式三选一，桌面与移动布局共用。
  Widget darkModeSection(BuildContext context, TUITheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            TIM_t("夜间模式"),
            style: TextStyle(
              fontSize: 15,
              color: theme.darkTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.weakDividerColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: DarkModeType.values
                .map((mode) => Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Provider.of<DefaultThemeData>(context, listen: false)
                              .darkMode = mode;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Provider.of<DefaultThemeData>(context)
                                        .darkMode ==
                                    mode
                                ? (theme.primaryColor ??
                                    CommonColor.primaryColor)
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              mode.label,
                              style: TextStyle(
                                fontSize: 14,
                                color: Provider.of<DefaultThemeData>(context)
                                            .darkMode ==
                                        mode
                                    ? Colors.white
                                    : theme.weakTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              darkModeSection(context, theme),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: skinBuilder()
                    .map((e) => Container(
                          margin: const EdgeInsets.only(right: 30),
                          child: e,
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        defaultWidget: Scaffold(
            appBar: AppBar(
              iconTheme: const IconThemeData(
                color: Colors.white,
              ),
              shadowColor: theme.weakDividerColor,
              elevation: 1,
              title: Text(
                TIM_t("更换皮肤"),
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.lightPrimaryColor ?? CommonColor.lightPrimaryColor,
                    theme.primaryColor ?? CommonColor.primaryColor
                  ]),
                ),
              ),
            ),
            body: Container(
                padding: const EdgeInsets.only(top: 16),
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                color: theme.weakBackgroundColor,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      darkModeSection(context, theme),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          TIM_t("主题色"),
                          style: TextStyle(
                            fontSize: 15,
                            color: theme.darkTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 16.0, // 主轴(水平)方向间距
                        runSpacing: 16.0, // 纵轴（垂直）方向间距
                        alignment: WrapAlignment.center, //沿主轴方向居中
                        children: skinBuilder(),
                      ),
                    ],
                  ),
                ))));
  }
}

class SkinCube extends StatelessWidget {
  final ThemeType currentThemeType;

  const SkinCube({Key? key, required this.currentThemeType}) : super(key: key);

  onThemeChanged(BuildContext context, ThemeType type) {
    if (currentThemeType != type) {
      Provider.of<DefaultThemeData>(context, listen: false).currentThemeType =
          currentThemeType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeType = Provider.of<DefaultThemeData>(context).currentThemeType;
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    return SizedBox(
        height: 128,
        width: MediaQuery.of(context).size.width * (isWideScreen ? 0.12 : 0.45),
        child: GestureDetector(
            onTap: () {
              onThemeChanged(context, themeType);
            },
            child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  gradient: LinearGradient(colors: [
                    DefTheme.defaultTheme[currentThemeType]!
                            .lightPrimaryColor ??
                        CommonColor.lightPrimaryColor,
                    DefTheme.defaultTheme[currentThemeType]!.primaryColor ??
                        CommonColor.primaryColor
                  ]),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Checkbox(
                          onChanged: (bool? value) {
                            if (value != null && value == true) {
                              onThemeChanged(context, themeType);
                            }
                          },
                          value: themeType == currentThemeType,
                          side: const BorderSide(color: Colors.white, width: 1),
                          shape: const CircleBorder()),
                    ),
                    Positioned(
                        bottom: 0,
                        child: Container(
                            width: MediaQuery.of(context).size.width *
                                (isWideScreen ? 0.12 : 0.45),
                            height: 32,
                            decoration: BoxDecoration(
                                color: Colors.black.withAlpha(64),
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(8))),
                            child: Center(
                                child: Text(
                                    TIM_t(DefTheme
                                        .defaultThemeName[currentThemeType]!),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16)))))
                  ],
                ))));
  }
}
