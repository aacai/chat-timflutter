import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectStatus{
  success,
  failed,
  connecting
}

/// 大文件分片大小预设（MB），上限低于 UIKit 的 100M 单文件限制，避免单片超限。
const List<int> chunkSizePresetsMB = [10, 30, 90];

class LocalSetting with ChangeNotifier {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  /// Record is show reading status in historical message list
  bool? _isShowReadingStatus;

  /// Record is show online status of other users
  bool? _isShowOnlineStatus;

  /// The connection status to Tencent Server
  ConnectStatus? _connectStatus;

  /// Interface Language
  String? _language;

  /// 大文件分片大小（MB），默认 90。
  int? _chunkSizeMB;

  ConnectStatus get connectStatus => _connectStatus ?? ConnectStatus.success;

  set connectStatus(ConnectStatus value) {
    _connectStatus = value;
    notifyListeners();
  }

  bool get isShowReadingStatus => _isShowReadingStatus ?? false;

  set isShowReadingStatus(bool value) {
    _isShowReadingStatus = value;
    notifyListeners();
    updateSettingsToLocal("isShowReadingStatus", value);
  }

  String? get language => _language;

  set language(String? value) {
    _language = value;
    notifyListeners();
    updateSettingsToLocalString("language", value ?? "en");
  }

  updateLanguageWithoutWriteLocal(String? value) {
    _language ??= value;
    notifyListeners();
  }

  bool get isShowOnlineStatus => _isShowOnlineStatus ?? true;

  set isShowOnlineStatus(bool value) {
    _isShowOnlineStatus = value;
    notifyListeners();
    updateSettingsToLocal("isShowOnlineStatus", value);
  }

  int get chunkSizeMB => _chunkSizeMB ?? chunkSizePresetsMB.last;

  set chunkSizeMB(int value) {
    _chunkSizeMB = value;
    notifyListeners();
    updateSettingsToLocal("chunkSizeMB", value);
  }

  loadSettingsFromLocal() async {
    SharedPreferences prefs = await _prefs;
    _isShowOnlineStatus = prefs.getBool("isShowOnlineStatus");
    _language = prefs.getString("language");
    _isShowReadingStatus = prefs.getBool("isShowReadingStatus");
    _chunkSizeMB = prefs.getInt("chunkSizeMB");
    notifyListeners();
  }

  updateSettingsToLocal(String setting, bool value) async{
    SharedPreferences prefs = await _prefs;
    prefs.setBool(setting, value);
  }

  updateSettingsToLocalString(String setting, String value) async{
    SharedPreferences prefs = await _prefs;
    prefs.setString(setting, value);
  }

  LocalSetting(){
    loadSettingsFromLocal();
  }
}