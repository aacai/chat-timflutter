import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/utils/auto_login_store.dart';

/// 登录态读写只在 AutoLoginStore 一处，退出登录后必须读不到任何可自动登录的信息。
void main() {
  const userIDKey = 'savedUserID';
  const enabledKey = 'autoLoginEnabled';
  const loginTimeKey = 'lastLoginTime';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AutoLoginStore.save', () {
    test('开启自动登录时写入三把 key', () async {
      await AutoLoginStore.save('alice', enabled: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(userIDKey), 'alice');
      expect(prefs.getBool(enabledKey), isTrue);
      expect(prefs.getInt(loginTimeKey), isNotNull);
      expect(await AutoLoginStore.usableUserID(), 'alice');
    });

    test('关闭自动登录时不留下任何凭据', () async {
      await AutoLoginStore.save('alice', enabled: true);
      await AutoLoginStore.save('alice', enabled: false);

      expect(await AutoLoginStore.savedUserID(), isNull);
      expect(await AutoLoginStore.isEnabled(), isFalse);
      expect(await AutoLoginStore.usableUserID(), isNull);
    });

    test('空 userID 等同于清除', () async {
      await AutoLoginStore.save('alice', enabled: true);
      await AutoLoginStore.save('', enabled: true);

      expect(await AutoLoginStore.savedUserID(), isNull);
    });
  });

  group('AutoLoginStore.usableUserID', () {
    test('开关关闭时即使有 userID 也不自动登录', () async {
      SharedPreferences.setMockInitialValues({
        userIDKey: 'alice',
        loginTimeKey: DateTime.now().millisecondsSinceEpoch,
      });

      expect(await AutoLoginStore.usableUserID(), isNull);
    });

    test('缺少登录时间戳时不自动登录', () async {
      SharedPreferences.setMockInitialValues({
        userIDKey: 'alice',
        enabledKey: true,
      });

      expect(await AutoLoginStore.usableUserID(), isNull);
    });

    test('超过 7 天的会话失效', () async {
      final expired = DateTime.now()
          .subtract(AutoLoginStore.sessionValidity + const Duration(minutes: 1))
          .millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        userIDKey: 'alice',
        enabledKey: true,
        loginTimeKey: expired,
      });

      expect(await AutoLoginStore.usableUserID(), isNull);
    });

    test('7 天内的会话仍然有效', () async {
      final soon = DateTime.now()
          .subtract(AutoLoginStore.sessionValidity - const Duration(minutes: 1))
          .millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        userIDKey: 'alice',
        enabledKey: true,
        loginTimeKey: soon,
      });

      expect(await AutoLoginStore.usableUserID(), 'alice');
    });
  });

  group('AutoLoginStore.clearAll', () {
    test('退出登录后读不到自动登录信息，但保留隐私协议同意状态', () async {
      SharedPreferences.setMockInitialValues({
        userIDKey: 'alice',
        enabledKey: true,
        loginTimeKey: DateTime.now().millisecondsSinceEpoch,
        'firstTime': 'true',
        'devLoginUserID': 'alice',
        'devUserSig': 'sig',
        'smsLoginToken': 'token',
        'smsLoginPhone': '13800000000',
      });

      await AutoLoginStore.clearAll();

      expect(await AutoLoginStore.usableUserID(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.contains('devLoginUserID'), isFalse);
      expect(prefs.contains('devUserSig'), isFalse);
      expect(prefs.contains('smsLoginToken'), isFalse);
      expect(prefs.contains('smsLoginPhone'), isFalse);
      expect(prefs.getString('firstTime'), 'true');
    });

    test('clearAutoLogin 不动短信登录的 key', () async {
      SharedPreferences.setMockInitialValues({
        userIDKey: 'alice',
        enabledKey: true,
        loginTimeKey: DateTime.now().millisecondsSinceEpoch,
        'smsLoginToken': 'token',
      });

      await AutoLoginStore.clearAutoLogin();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.contains('smsLoginToken'), isTrue);
      expect(await AutoLoginStore.usableUserID(), isNull);
    });
  });

  test('disable 关掉自动登录但保留用户名', () async {
    await AutoLoginStore.save('alice', enabled: true);

    await AutoLoginStore.disable();

    expect(await AutoLoginStore.isEnabled(), isFalse);
    expect(await AutoLoginStore.usableUserID(), isNull);
    expect(await AutoLoginStore.savedUserID(), 'alice');
  });
}
