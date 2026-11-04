import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/app_navigation.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/contact_and_profile.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/me_and_tencent.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/left_bar.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'conversation_and_chat.dart';
import 'package:provider/provider.dart';

class HomePageWideScreen extends StatefulWidget {
  const HomePageWideScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomePageWideScreenState();
}

class HomePageWideScreenState extends State<HomePageWideScreen> {
  final V2TIMManager _sdkInstance = TIMUIKitCore.getSDKInstance();

  int homePageIndex = 0;
  V2TimConversation? currentConversation;

  @override
  initState() {
    super.initState();
    getLoginUserInfo();
    // 宽屏主页是根路由，没有可 pop 的上一级；返回统一切回「消息」tab。
    AppNavigation.onRootBack = () {
      if (mounted) {
        setState(() => homePageIndex = 0);
      }
    };
  }

  @override
  void dispose() {
    if (AppNavigation.onRootBack != null) {
      AppNavigation.onRootBack = null;
    }
    super.dispose();
  }

  _navigateToChat(V2TimConversation conversation) {
    setState(() {
      homePageIndex = 0;
      currentConversation = conversation;
    });
  }

  getLoginUserInfo() async {
    if (PlatformUtils().isWeb) {
      return;
    }
    final res = await _sdkInstance.getLoginUser();
    if (res.code == 0) {
      final result = await _sdkInstance.getUsersInfo(userIDList: [res.data!]);

      if (result.code == 0) {
        Provider.of<LoginUserInfo>(context, listen: false)
            .setLoginUserInfo(result.data![0]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          decoration: BoxDecoration(
            color: hexToColor("2E3440"),
          ),
          child: Column(
            children: [
              // 宽屏主页是根路由，给一个始终可见的返回入口：
              // 有上级就 pop，没有就切回「消息」tab，不会出现死路。
              SizedBox(
                height: 40,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 17),
                  color: AppColors.onPrimary,
                  tooltip: TIM_t("返回"),
                  onPressed: () => AppNavigation.back(context),
                ),
              ),
              Expanded(
                child: LeftBar(
                  index: homePageIndex,
                  onChange: (index) {
                    setState(() {
                      homePageIndex = index;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
            child: Column(
              children: [
                if(PlatformUtils().isWindows) Container(
                  height: 40,
                  decoration: BoxDecoration(
                      color: hexToColor("2E3440")),
                child: Row(
                  children: [
                    Expanded(child: MoveWindow()),
                    MinimizeWindowButton(colors: WindowButtonColors(
                      iconNormal: AppColors.onPrimary
                    ),),
                    MaximizeWindowButton(colors: WindowButtonColors(
                        iconNormal: AppColors.onPrimary
                    ),),
                    CloseWindowButton(colors: WindowButtonColors(
                        iconNormal: AppColors.onPrimary
                    ),)
                  ],
                ),),
                Expanded(child: IndexedStack(
                  index: homePageIndex,
                  children: [
                    ConversationAndChat(conversation: currentConversation,),
                    ContactsAndProfile(onNavigateToChat: _navigateToChat),
                    const MeAndTencent(),
                  ],
                ))
              ],
            )
        )
      ],
    );
  }
}
