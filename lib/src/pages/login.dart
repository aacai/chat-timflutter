// ignore_for_file: unused_import, avoid_print

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
          resizeToAvoidBottomInset: false,
        ));
  }
}

class AppLayout extends StatelessWidget {
  final Function? initIMSDK;
  const AppLayout({Key? key, this.initIMSDK}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return GestureDetector(
      onTap: () {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      },
      child: Container(
        color: theme.weakBackgroundColor,
        child: Column(
          children: [
            const AppLogo(),
            Expanded(
              child: LoginForm(
                initIMSDK: initIMSDK,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 48,
        bottom: 40,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.lightPrimaryColor ?? CommonColor.lightPrimaryColor,
            theme.primaryColor ?? CommonColor.primaryColor
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 64,
            width: 64,
            child: Image.asset(
              "assets/logo_transparent.png",
              color: Colors.white,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            TIM_t("腾讯云即时通信IM"),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TIM_t("欢迎使用本 APP 体验腾讯云 IM 产品服务"),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
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
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CupertinoAlertDialog(
          content: Text.rich(
            TextSpan(style: const TextStyle(fontSize: 14, color: Colors.black, height: 2.0), children: [
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

      await TUICallKit.instance.login(sdkAppId, userID, userSig);

      var data = await coreInstance.login(
        userID: userID,
        userSig: userSig,
      );
      if (data.code != 0) {
        final option1 = data.desc;
        final msg = TIM_t_para("登录失败{{option1}}", "登录失败$option1")(option1: option1);
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
    } catch (e) {
      // 登录过程抛异常（网络/SDK 等）时静默失败无提示，这里显式暴露原因。
      final msg = "登录失败：$e";
      setState(() {
        _loginError = msg;
      });
      ToastUtils.toast(msg);
    } finally {
      _isLoggingIn = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final primary = theme.primaryColor ?? CommonColor.primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24).copyWith(
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.weakBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TIM_t("用户名"),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintText: TIM_t("请输入用户名"),
                  hintStyle:
                      TextStyle(fontSize: 15, color: theme.weakTextColor),
                  filled: true,
                  fillColor: theme.weakBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: theme.weakDividerColor ?? Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: primary, width: 1.5),
                  ),
                ),
                keyboardType: TextInputType.text,
                onChanged: (v) {
                  setState(() {
                    userID = v;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: _autoLogin,
                      activeColor: primary,
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
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoggingIn ? null : userLogin,
                  child: _isLoggingIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
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
            ],
          ),
        ),
      ),
    );
  }
}
