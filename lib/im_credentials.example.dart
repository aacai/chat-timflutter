/// 凭据的入库副本：CI 用 .github/actions/im-credentials 把它拷成 lib/im_credentials.dart
/// （那个路径在 .gitignore 里，flutter 构建真正读的是它）。改凭据只改这个文件。
/// 本仓是公开仓库，这两行等于公开——按 2026-11-02 用户「不怕泄露」的决定执行。
class ImCredentials {
  static const int sdkAppID = 1600012202;
  static const String key = "d9e0a81f19203871901bfc0a236d03f569f09acbcb7c14a5c851a4d883dfeca0";
}
