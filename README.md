# chat-timflutter

腾讯云 IM Flutter UIKit 的 demo 工程 fork。上游 [Tencent-RTC/tim_flutter_demo](https://github.com/Tencent-RTC/tim_flutter_demo) 已声明停止维护（原 README.md 就是一则废弃通告），这里保留并继续开发我们自己的即时通讯客户端。

## 本地跑起来

需要 Flutter 3.41.x（CI 用的版本记录在 [.github/workflows/build.yml](.github/workflows/build.yml) 的 `FLUTTER_VERSION`）。

```bash
cp lib/im_credentials.example.dart lib/im_credentials.dart   # 填入你的 sdkAppID / secretKey
flutter pub get
flutter run
```

`lib/im_credentials.dart` 没有入库，`.gitignore` 里挡掉了：里面的 `secretKey` 用来在本地生成 UserSig，一旦提交就等于把 IM 的签名私钥公开。构建时没有它也能编译通过（CI 会退回示例文件），但登录不了。

`linux/out/` 与 `web/node_modules/` 里有上游误提交的构建产物仍被 git 跟踪，别去动它们做实验。

## 依赖版本是锁死的

`pubspec.yaml` 里 4 个腾讯 IM 包（uikit / sdk / push / calls_uikit）用精确版本号，不用 `^`。原因是这些包的 `pubspec.lock` 不入库，CI 每次都会挑最新版，而最新版会连带换掉 macOS/iOS 的原生 pod——`tencent_cloud_chat_sdk 8.9.7545` 就是这样把 macOS 的 `pod install` 搞挂的。要升级就四个一起升，并跑一遍三平台构建。

CI 在 `flutter pub get` 之后会执行 [.github/actions/patch-uikit-linux](.github/actions/patch-uikit-linux)：上游 uikit 5.0.1 全系列有两处 URI 在区分大小写的文件系统上编不过（`video_screen.dart` 的目录大小写笔误，和 `tim_uikit_group_button_area.dart` 的 `import '/theme/...'` 根路径写法）。macOS/Windows 蒙得住，Linux runner 必挂，所以改的是 pub 缓存副本，不动仓库。

## GitHub Actions

push 到 `mycustom-feature` 或打 `v*` tag 触发 [build.yml](.github/workflows/build.yml)：

| job | runner | 产物 |
| --- | --- | --- |
| analyze & test | ubuntu-latest | `dart analyze` + `flutter test`，后面所有 job 的前置 |
| android arm64-v8a | ubuntu-latest | 单个 APK（gradle 的 `abiFilters` 已只留 arm64-v8a） |
| windows x64 | windows-latest | zip |
| macos arm64 | macos-14（本身就是 arm64） | zip |

只出 64 位单架构产物，不做 fat 包：混架构会让 APK 白带上 x86_64/armv7 的原生库。tag 推送时三个平台的产物由「发 Release」job 汇总成 Release 附件。

需要在仓库 Secrets 里配 `IM_SDK_APP_ID` 和 `IM_SECRET_KEY`（[.github/actions/im-credentials](.github/actions/im-credentials) 生成 `lib/im_credentials.dart`）。没配也能构建成功，只是产物登录不了。

## 我们自己的功能

- **自动登录**：7 天内的会话免登录，开关在登录页；退出登录会清干净本地登录态（`lib/utils/auto_login_store.dart`），不会被自动重登顶回去。
- **大文件分片**：超过 100MB 的单文件自动切片发送，界面上仍然只有一条文件气泡，分片气泡不渲染，收齐后自动合并（`lib/utils/file_transfer/`）。分片元数据放在消息的 `cloudCustomData` 里，不占文件名。
- **自有加密**：算法层在 [lib/utils/secure_channel/secure_channel.dart](lib/utils/secure_channel/secure_channel.dart)，X25519 临时密钥协商 + HKDF-SHA256 + ChaCha20-Poly1305，单测覆盖越权/篡改/截断。尚未接到消息与文件收发路径上——uikit 没有发送前的钩子（`ChatLifeCycle.messageWillSend` 是注释掉的），且 `MessageService` 在 `setupServiceLocator()` 里就被抓进各 ViewModel 的 final 字段，事后重新注册看不见。接入前要先解决身份私钥的落盘方式，以及三处明文泄漏：`offlinePushInfo.desc`、引用回复写进 `cloudCustomData` 的原文、发给腾讯的翻译请求。

## iOS / macOS 构建注意事项

见 [BUILD.md](BUILD.md)（CocoaPods 仓库过期、`pod deintegrate` 重装等）。
