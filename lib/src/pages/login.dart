// ignore_for_file: unused_import, avoid_print

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/pages/home_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/privacy/privacy_webview.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/routes.dart';
import 'package:tencent_cloud_chat_demo/utils/GenerateTestUserSig.dart';
import 'package:tencent_cloud_chat_demo/utils/auto_login_store.dart';
import 'package:tencent_cloud_chat_demo/utils/commonUtils.dart';
import 'package:tencent_cloud_chat_demo/utils/secure_channel/encryption_service.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';

class LoginPage extends StatelessWidget {
  final Function? initIMSDK;
  const LoginPage({Key? key, this.initIMSDK}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: Scaffold(
          body: AppLayout(initIMSDK: initIMSDK),
          // 移动端弹键盘时要上推布局，否则输入框被遮挡；
          // 桌面端没有软键盘，这个属性无副作用。
          resizeToAvoidBottomInset: true,
        ));
  }
}

class AppLayout extends StatelessWidget {
  final Function? initIMSDK;
  const AppLayout({Key? key, this.initIMSDK}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽屏（桌面/平板）左右分栏，窄屏（手机）上下结构。
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            children: [
              const Expanded(flex: 5, child: AppLogo()),
              Expanded(
                flex: 4,
                child: LoginForm(initIMSDK: initIMSDK),
              ),
            ],
          );
        }
        return Column(
          children: [
            const AppLogo(compact: true),
            Expanded(
              child: LoginForm(initIMSDK: initIMSDK),
            ),
          ],
        );
      },
    );
  }
}

class AppLogo extends StatelessWidget {
  /// true：窄屏顶部品牌头；false：宽屏左侧整栏品牌区。
  final bool compact;
  const AppLogo({Key? key, this.compact = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = theme.primaryColor ?? CommonColor.primaryColor;
    final titleColor = isDark ? AppColors.onSurfaceOf(context) : theme.darkTextColor;
    final subtitleColor = isDark ? AppColors.weakTextOf(context) : theme.weakTextColor;

    // 原来是一张白色大图压在饱和渐变上，又白又大很扎眼。
    // 改成主色圆角容器里的小图标，靠留白和排版撑起品牌区。
    final mark = Container(
      width: compact ? 40 : 64,
      height: compact ? 40 : 64,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(compact ? 12 : 18),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: compact ? 10 : 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(compact ? 9 : 14),
      child: Image.asset(
        "assets/logo_transparent.png",
        fit: BoxFit.contain,
      ),
    );

    final title = Text(
      "可达",
      style: TextStyle(
        color: titleColor,
        fontSize: compact ? 20 : 32,
        fontWeight: FontWeight.w700,
        letterSpacing: compact ? 0.5 : 1,
      ),
    );

    final subtitle = Text(
      TIM_t("安全、高效、值得信赖的即时通讯"),
      style: TextStyle(color: subtitleColor, fontSize: compact ? 12 : 14),
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 28,
          bottom: 24,
          left: 28,
          right: 28,
        ),
        color: isDark ? AppColors.onPrimary.withOpacity(0.03) : primary.withOpacity(0.04),
        child: Row(
          children: [
            mark,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  const SizedBox(height: 2),
                  subtitle,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withOpacity(isDark ? 0.24 : 0.10),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              mark,
              const SizedBox(height: 28),
              title,
              const SizedBox(height: 10),
              subtitle,
            ],
          ),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final Function? initIMSDK;
  const LoginForm({Key? key, required this.initIMSDK}) : super(key: key);

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final CoreServicesImpl coreInstance = TIMUIKitCore.getInstance();

  String userID = 'n';
  final TextEditingController _userIdController = TextEditingController(text: 'n');
  bool _autoLogin = true;
  String? _loginError;

  @override
  initState() {
    super.initState();
    checkFirstEnter();
    loadSavedUserInfo();
    if (widget.initIMSDK != null) {
      widget.initIMSDK!();
    }
  }

  TextSpan webViewLink(String title, String url) {
    return TextSpan(
      text: TIM_t(title),
      style: const TextStyle(
        color: Color.fromRGBO(0, 110, 253, 1),
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyDocument(title: title, url: url)));
        },
    );
  }

  void checkFirstEnter() async {
    Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
    SharedPreferences prefs = await _prefs;
    String? firstTime = prefs.getString("firstTime");
    if (firstTime != null && firstTime == "true") {
      return;
    }
    // 读取 SharedPreferences 是异步的，这期间页面可能已经被卸载，
    // 此时再弹窗等于往已 dispose 的 Navigator 里塞路由。
    if (!mounted) {
      return;
    }
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CupertinoAlertDialog(
          content: Text.rich(
            TextSpan(style: const TextStyle(fontSize: 14, color: Color(0xFF1F2329), height: 2.0), children: [
              TextSpan(
                text: TIM_t("欢迎使用腾讯云即时通信 IM，为保护您的个人信息安全，我们更新了《隐私政策》，主要完善了收集用户信息的具体内容和目的、增加了第三方SDK使用等方面的内容。"),
              ),
              const TextSpan(
                text: "\n",
              ),
              TextSpan(
                text: TIM_t("请您点击"),
              ),
              webViewLink("《用户协议》", 'https://web.sdk.qcloud.com/document/Tencent-IM-User-Agreement.html'),
              TextSpan(
                text: TIM_t(", "),
              ),
              webViewLink("《隐私协议》", 'https://privacy.qq.com/document/preview/1cfe904fb7004b8ab1193a55857f7272'),
              TextSpan(
                text: TIM_t(", "),
              ),
              webViewLink("《信息收集清单》", 'https://privacy.qq.com/document/preview/45ba982a1ce6493597a00f8c86b52a1e'),
              TextSpan(
                text: TIM_t("和"),
              ),
              webViewLink("《信息共享清单》", 'https://privacy.qq.com/document/preview/dea84ac4bb88454794928b77126e9246'),
              TextSpan(text: TIM_t("并仔细阅读，如您同意以上内容，请点击“同意并继续”，开始使用我们的产品与服务！")),
            ]),
            overflow: TextOverflow.clip,
          ),
          actions: [
            CupertinoButton(
                child: Text(TIM_t("同意并继续"), style: const TextStyle(color: Colors.blue, fontSize: 16)),
              onPressed: () {
                prefs.setString("firstTime", "true");
                Navigator.of(context).pop(true);
              },
            ),
            CupertinoButton(
              child: Text(TIM_t("不同意并退出"), style: const TextStyle(color: Colors.grey, fontSize: 16)),
              onPressed: () {
                exit(0);
              },
            ),
          ],
        );
      },
    );
  }

  void loadSavedUserInfo() async {
    // 退出登录会清掉保存的用户名，这里读不到就说明上一次是主动退出或已被踢下线。
    final savedUserID = await AutoLoginStore.savedUserID();
    final enabled = await AutoLoginStore.isEnabled();
    final autoLoginUserID = await AutoLoginStore.usableUserID();
    if (!mounted) {
      return;
    }
    setState(() {
      _autoLogin = enabled;
      if (savedUserID != null && savedUserID.isNotEmpty) {
        userID = savedUserID;
        _userIdController.text = savedUserID;
      }
    });

    if (autoLoginUserID == null) {
      return;
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      userLogin();
    });
  }

  Future<void> saveUserInfo() async {
    await AutoLoginStore.save(userID.trim(), enabled: _autoLogin);
  }

  /// 自动登录失败时关掉开关但保留用户名，否则被踢下线会形成登录-被踢死循环。
  Future<void> _disableAutoLogin() async {
    await AutoLoginStore.disable();
    if (mounted) {
      setState(() {
        _autoLogin = false;
      });
    }
  }

  directToHomePage() {
    Routes().directToHomePage();
  }

  bool _isLoggingIn = false;

  userLogin() async {
    if (_isLoggingIn) {
      return;
    }
    if (userID.trim() == '') {
      ToastUtils.toast(TIM_t("请输入用户名"));
      return;
    }

    String key = IMDemoConfig.key;
    int sdkAppId = IMDemoConfig.sdkAppID;
    if (key == "" || sdkAppId == 0) {
      ToastUtils.toast(TIM_t("请在 im_credentials.dart 中输入 sdkAppID 和 key"));
      return;
    }
    setState(() {
      _loginError = null;
    });
    _isLoggingIn = true;
    try {
      GenerateTestUserSig generateTestUserSig = GenerateTestUserSig(
        sdkappid: sdkAppId,
        key: key,
      );

      String userSig = generateTestUserSig.genSig(identifier: userID, expire: 99999);

      // 音视频通话 TUICallKit 在桌面端（macOS/Windows）支持有限，login 可能抛错，
      // 这里隔离它，失败不能阻塞 IM 登录本身，否则整个登录都会失败。
      try {
        await TUICallKit.instance.login(sdkAppId, userID, userSig);
      } catch (callKitError) {
        debugPrint("TUICallKit login skipped: $callKitError");
      }

      var data = await coreInstance.login(
        userID: userID,
        userSig: userSig,
      );
      if (data.code != 0) {
        final option1 = data.desc;
        final msg = TIM_t_para("登录失败{{option1}}", "登录失败$option1")(option1: option1);
        if (!mounted) {
          return;
        }
        setState(() {
          _loginError = msg;
        });
        ToastUtils.toast(msg);
        // 自动登录失败不再保留开关，交给用户手动登录，避免反复弹登录失败。
        await _disableAutoLogin();
        return;
      }

      // 登录成功后才落盘登录态，保存失败不影响本次会话。
      await saveUserInfo();

      // 生成并发布端到端加密身份公钥（个人签名），供对端取用。
      await EncryptionService.instance.init();

      directToHomePage();
    } catch (e, s) {
      // 登录过程抛异常（网络/SDK 等）时静默失败无提示，这里显式暴露原因。
      debugPrint("login failed: $e\n$s");
      final msg = "登录失败：$e";
      if (mounted) {
        setState(() {
          _loginError = msg;
        });
      }
      ToastUtils.toast(msg);
    } finally {
      _isLoggingIn = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final primary = theme.primaryColor ?? CommonColor.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppColors.surfaceOf(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    final fieldBorderColor = AppColors.dividerOf(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 48 : 24,
          vertical: 24,
        ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TIM_t("欢迎回来"),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: theme.darkTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    TIM_t("登录以继续使用"),
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.weakTextColor,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    TIM_t("用户名"),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: theme.darkTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _userIdController,
                    autofocus: false,
                    style: TextStyle(
                      color: theme.darkTextColor,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      hintText: TIM_t("请输入用户名"),
                      hintStyle: TextStyle(fontSize: 15, color: theme.weakTextColor),
                      filled: true,
                      fillColor: AppColors.inputFillOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: fieldBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: fieldBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primary, width: 1.5),
                      ),
                    ),
                    keyboardType: TextInputType.text,
                    onChanged: (v) {
                      setState(() {
                        userID = v;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          value: _autoLogin,
                          activeColor: primary,
                          side: BorderSide(color: fieldBorderColor),
                          onChanged: (bool? value) {
                            setState(() {
                              _autoLogin = value ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        TIM_t("自动登录"),
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.weakTextColor,
                        ),
                      ),
                    ],
                  ),
                  if (_loginError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _loginError!,
                        style: const TextStyle(
                          color: Color(0xFFE5484D),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: AppColors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isLoggingIn ? null : userLogin,
                      child: _isLoggingIn
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              TIM_t("登录"),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      TIM_t("首次登录将自动创建账号"),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.weakTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
