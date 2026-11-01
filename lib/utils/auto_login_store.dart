import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';

/// 登录态的唯一读写处。
///
/// 自动登录只保存 userID：UserSig 每次启动用本地 secretKey 重新生成，不落盘。
/// 因此「退出登录」必须删掉这三把 key，否则下次启动会自动重新登录回去。
class AutoLoginStore {
  static const String _userIDKey = 'savedUserID';
  static const String _enabledKey = 'autoLoginEnabled';
  static const String _loginTimeKey = 'lastLoginTime';

  static const Duration sessionValidity = Duration(days: 7);

  /// 返回可自动登录的 userID；未开启、缺失或超过 [AutoLoginStore.sessionValidity] 时返回 null。
  static Future<String?> usableUserID() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_enabledKey) != true) {
      return null;
    }
    final userID = prefs.getString(_userIDKey);
    if (userID == null || userID.isEmpty) {
      return null;
    }
    final lastLoginTime = prefs.getInt(_loginTimeKey);
    if (lastLoginTime == null) {
      return null;
    }
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastLoginTime;
    if (elapsed >= sessionValidity.inMilliseconds) {
      return null;
    }
    return userID;
  }

  static Future<String?> savedUserID() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIDKey);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// 自动登录失败后关掉开关但保留用户名，下次至少能预填，也不会反复弹失败提示。
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  static Future<void> save(String userID, {required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!enabled || userID.isEmpty) {
      await clearAutoLogin();
      return;
    }
    await prefs.setString(_userIDKey, userID);
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_loginTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// 退出登录时被踢下线时调用：清掉登录凭据，但保留隐私协议同意状态与主题设置。
  static Future<void> clearAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIDKey);
    await prefs.remove(_enabledKey);
    await prefs.remove(_loginTimeKey);
  }

  /// 退出登录 / 被踢下线时需要清除的全部本地登录态。
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await clearAutoLogin();
    for (final key in const [
      Const.DEV_LOGIN_USER_ID,
      Const.DEV_LOGIN_USER_SIG,
      Const.SMS_LOGIN_TOKEN,
      Const.SMS_LOGIN_PHONE,
    ]) {
      await prefs.remove(key);
    }
  }
}
