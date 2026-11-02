# chat-timflutter

腾讯云 IM Flutter UIKit 的 demo 工程 fork。上游 [Tencent-RTC/tim_flutter_demo](https://github.com/Tencent-RTC/tim_flutter_demo) 已声明停止维护（原 README.md 就是一则废弃通告），这里保留并继续开发我们自己的即时通讯客户端，产品名叫**可达**。

显示名散在几处，改名要一次改齐：`android/app/src/main/AndroidManifest.xml` 的 `android:label`、`lib/main.dart` 的 `MaterialApp.title`、`macos/Runner/Configs/AppInfo.xcconfig` 的 `PRODUCT_NAME`（`.app` 文件名跟着它走，`Runner.xcodeproj` 里的 `path`/`BuildableName` 和 `INFOPLIST_KEY_CFBundleDisplayName` 要一起改）、`windows/runner/main.cpp` 的窗口标题、`windows/runner/Runner.rc` 的 `FileDescription`/`ProductName`、以及 `packaging/windows/` 那两份安装脚本。三处中文各有编码前提：`.iss` 必须存成 UTF-8 with BOM，MSI 必须 `Language="2052"`（1033 的代码页装不下汉字），C++ 源码里的标题用 `\u` 转义而不是裸中文（runner 没开 `/utf-8`）。安装目录刻意留 ASCII（`Program Files\KeDa`）。iOS 与 Web 侧还是上游名字——没有发布路径经过它们。

## 本地跑起来

需要 Flutter 3.41.x（CI 用的版本记录在 [.github/workflows/build.yml](.github/workflows/build.yml) 的 `FLUTTER_VERSION`）。

```bash
cp lib/im_credentials.example.dart lib/im_credentials.dart   # 凭据已入库，直接拷
flutter pub get
flutter run
```

`lib/im_credentials.dart` 没入库（`.gitignore` 挡掉了），构建实际读的是它；内容来自入库的 [lib/im_credentials.example.dart](lib/im_credentials.example.dart)，本地和 CI 都是 `cp` 一下。
这两份凭据是按 2026-11-02 的决定**明文提交**的——本仓公开可读，`secretKey` 谁都能拿到，任何人都能用它给自己签发 UserSig。要收回这个口子，就换掉控制台里的 key 并把 `example` 文件拨回占位值。

`linux/out/` 与 `web/node_modules/` 里有上游误提交的构建产物仍被 git 跟踪，别去动它们做实验。

## 依赖版本是锁死的

`pubspec.yaml` 里 4 个腾讯 IM 包（uikit / sdk / push / calls_uikit）用精确版本号，不用 `^`。原因是这些包的 `pubspec.lock` 不入库，CI 每次都会挑最新版，而最新版会连带换掉 macOS/iOS 的原生 pod——`tencent_cloud_chat_sdk 8.9.7545` 就是这样把 macOS 的 `pod install` 搞挂的。要升级就四个一起升，并跑一遍三平台构建。

CI 在 `flutter pub get` 之后会执行 [.github/actions/patch-uikit-linux](.github/actions/patch-uikit-linux)：上游 uikit 5.0.1 全系列有两处 URI 在区分大小写的文件系统上编不过（`video_screen.dart` 的目录大小写笔误，和 `tim_uikit_group_button_area.dart` 的 `import '/theme/...'` 根路径写法）。macOS/Windows 蒙得住，Linux runner 必挂，所以改的是 pub 缓存副本，不动仓库。

## GitHub Actions

push 到 `mycustom-feature` 或打 `v*` tag 触发 [build.yml](.github/workflows/build.yml)：

| job | runner | 产物 |
| --- | --- | --- |
| analyze & test | ubuntu-latest | `dart analyze` + `flutter test`，后面所有 job 的前置 |
| android arm64-v8a | ubuntu-latest | 单个 APK（`--target-platform=android-arm64`，构建后校验包内只剩一个 ABI） |
| windows x64 | windows-latest | Inno Setup `chat-timflutter-windows-x64-setup.exe` + WiX `chat-timflutter-windows-x64.msi`（两个都在 runner 上静默装/卸一遍再上传） |
| macos arm64 | macos-latest（arm64 runner，不交叉编 x86_64） | 拖拽式 `chat-timflutter-macos-arm64.dmg`（含 `/Applications` 快捷方式） |

桌面端不发 zip：解压即安装的方式要求用户自己找位置、自己建快捷方式，不算交付。
Windows 出两枚，装到同一个目录 `Program Files\KeDa`（显示名是中文「可达」，路径刻意留 ASCII），但**是两个独立产品，互不覆盖**：
`.exe` 由 [packaging/windows/setup.iss](packaging/windows/setup.iss) 编（Inno 的 `AppId` 是固定 GUID），
`.msi` 由 [packaging/windows/msi/product.wxs](packaging/windows/msi/product.wxs) 编（`UpgradeCode` 另一个固定 GUID，
文件表不手抄——CI 用 `heat.exe` 对整个 Release 目录 harvest，组件 GUID 用 `-g` 播种保证每次构建一致）。
两边的版本号都从 `APP_VERSION`（也就是 tag 名）读；MSI 的 `ProductVersion` 只收 `主.次.构建`，
非 tag 构建退成 `0.0.0`。`.exe` 有安装向导，`.msi` 只有 Windows Installer 的基础进度条，走 AD/GPO 分发用它。
两个都没做代码签名，也没公证：Windows 会弹 SmartScreen，macOS 首次打开要右键「打开」。

**Linux 不出包，不是 CI 少配了一个 job，是 SDK 没有 Linux 的原生库。**
`tencent_cloud_chat_sdk` 的 pubspec 只声明 android / ios / macos / windows / ohos，pub 包里没有
`linux/` 目录也没有 `libdart_native_imsdk.so`；而它的 FFI 加载器在 `Platform.isLinux` 分支就是要
`DynamicLibrary.open('libdart_native_imsdk.so')`（包内 `lib/native_im/bindings/native_library_manager.dart:47`）。
所以 `flutter build linux` 编得过、窗口也起得来，IM 一初始化就挂——发一枚登不进去的 deb 比不发更糟。
腾讯云文档里 Flutter Chat SDK 的支持平台表也没列 Linux。要补这一档，得先拿到官方 Linux 原生 SDK。
（[.github/actions/patch-uikit-linux](.github/actions/patch-uikit-linux) 修的是 uikit 两处 URI 在大小写敏感文件系统上编不过的问题，
那是 `dart analyze` 就要踩的坑，跟能不能跑起来是两回事。）

只出 64 位单架构产物，不做 fat 包。gradle 里的 `abiFilters 'arm64-v8a'` 单独写是无效的：
`flutter build apk` 默认 `--target-platform=android-arm,android-arm64,android-x64`，会按这个列表把
三个 ABI 的 `libapp.so` 合进同一个包——实测过一枚 198.6MB 的 APK 里 154.6MB 是原生库，
其中 100.9MB 是 armv7 和 x86_64 的废副本。`--target-platform=android-arm64` 只治了 Dart 侧（145.0MB），
插件 AAR 的 `jni/` 仍带三个架构，得再加 `packagingOptions.jniLibs.excludes` 按路径排。
两项一起才落到 **95.2MB**，包内只剩 `lib/arm64-v8a`（CI 构建完用 `unzip -Z1` 核对，多架构直接判红）。

APK 里的 `.so` 是 stored 不压缩的（AGP 默认 `extractNativeLibs=false`，直接 mmap 包内偏移），
所以原生库那 39.9M 是一字节不缩地进包的；webp 和 mp3 同理，都在 Flutter 的 noCompress 名单里。
按压缩后实占，构成是：
`lib/arm64-v8a` 39.9M（`libapp.so` 11.5 + `libflutter.so` 10.8 + `libliteavsdk.so` 7.85 +
`libImSDK.so` 3.7 + `libtuikitengineroom.so` 2.75 + `libtxffmpeg.so` 1.99 + 零星若干，共 10 个）、
dex 4.3M、sticker 插件表情 2.5M、导览图 2.2M、通话铃声 mp3 2.0M、自定义表情 1.1M、resources.arsc 0.42M。

体积是一路量着降下来的，不是估的：198.6MB（三个 ABI 杂糅）→ 145.0（`--target-platform`）
→ 95.2（`jniLibs.excludes` 排掉插件 AAR 的 jni）→ 93.1（删掉没人引用的 256 面国旗）
→ 88.4（删掉 `assets/live/`，全仓零引用的礼物动效）→ 79.6（导览截图 PNG→webp q90，10.6M→2.2M）
→ 69.1（排掉 `ffmpeg-android-java` 的 9.0M + 删 21 张零引用图 1.0M）
→ 58.8（`liteavSdk` 把 LiteAVSDK_Professional 换成 LiteAVSDK_TRTC：`.so` −9.2M、dex −0.6M）
→ **57.2**（`resConfigs` 砍 locale：arsc −1.02M + 品牌图降采样转 webp：−0.52M）。
排序必须按 compress_size：PNG/MP3/SO/WEBP 是 stored（实占=原值），json/dex 是 deflate（看着大、实际小一半），
按解压体积排优先级会排错。

`resConfigs 'en', 'zh'` 这一刀的量法：`resources.arsc` 是 stored 的，1,466,444 字节全是实占，
`aapt2 dump resources` 数出来里面 610K 字符串字节有 566K（93%）带语言限定，138 个 locale
（含 `es-r419`、`mai` 这类不规则写法），全是 AAR 自带的翻译。砍完产物里只剩 default + zh + en，
config 条目 17,268 → 4,648（−73%），arsc 1.40M → 0.42M。关键的反证是**非语言 config 一个没掉**：
密度、night、land、sw600dp、v28 这 37 种 config 前后都在（旧 176 种 = default + 138 语言 + 37 其它，
新 40 种 = default + zh + en + 同样那 37 种），说明这条只吃 locale，没顺手删掉密度和深色模式。
Dart 的文案在 flutter_assets 里，`resConfigs` 轮不到它——所以这刀只影响原生资源
（推送通知的渠道名、SDK 的错误提示串那些）。
AGP 的坑：库里若有 `dummy_locale` 资源，`resConfigs` 会把整个 assets 目录删空；
本包 dump 过 AndroidManifest，无该项，CI 里还留了 `flutter_assets 条目 ≥400`（实测 452）兜底。

品牌图那 0.52M 是另一类问题：上游按设计稿原始尺寸发的图，`qq.png` 2843×1305 实际只渲染 `height:35`，
`telegram.png` 1024×1024 渲染 `height:80`，超 4-12 倍。降到 698/320 再转 lossless webp。
一律 lossless 不用 q90：实测有损会把 logo 渐变唯一颜色从 147 涨到 924、中线 >2 的跳变从 68 涨到 109，
是看得见的色阶断裂，而 lossless 总共只多要 85K。逐像素核对过（自己解 PNG 的 IDAT，
`sips`/`dwebp` 会做格式归一化不可信）：alpha 通道 0 差异、不透明像素 RGB 0 差异，
两张二维码源图没有半透明像素所以连 RGB 都全等；只有半透明边缘的 RGB 会变，
那是 webp 存预乘 alpha 的固有行为，合成结果不变。

`assets/armeabi-v7a/ffmpeg` 那 9.0M（解压 17.6M）是 `com.github.RoleWong:ffmpeg-android-java:v0.6`
发的 32 位专用二进制，两层教训：
1. `packagingOptions.exclude` 对依赖合并进来的 assets 无效——精确路径和通配都试过，产物纹丝不动；
   要拆只能排依赖，现在写在 `android/app/build.gradle` 的 `configurations.all { exclude ... }`。
2. 它本来就是死代码。转换只在 `FlutterPluginRecordPlugin.initRecordMp3()` 里触发，
   而 uikit 录音走 `SoundPlayer.initSoundPlayer()` → `_recorder.init()`（`sound_record.dart:22`），
   `init()` 把 `recordMp3` 置 false，`stop()` 直接把 `.wav` 路径回传——语音消息上传的一直是 wav。
   之前误判成「拆不掉」，是因为只反解到 R8 改名后的 `c8.c → F2.a → L3.c` 这条**静态可达**链就收了工，
   没去看 Dart 侧到底调不调 `initRecordMp3`；静态可达不等于会执行。CI 现在盯着这个前提：
   有包引用 `initRecordMp3` 就让构建报红，产物里残留 32 位二进制也让构建报红。

LiteAVSDK 那一刀走的是官方留的口子，不是硬改：`tencent_calls_uikit-2.9.3/android/build.gradle:54`
认 `rootProject.ext.liteavSdk`，所以值写在根 `android/gradle.properties` 里就能把默认的
Professional（arm64 `.so` 19.25M）换成 TRTC（10.08M）。换之前先做类引用普查——calls 插件只用到 3 个
SDK 类型、rtc_room_engine 用到 23 个，全部落在 TRTC 也有的符号里，`tuicore` 则一个 SDK 类都不引用；
换完再对产物做 `dexdump -h` 反证：thumbplayer / hiteshsondhi88 / adriel 定义数为 0，
TRTCCloud 129、liteav 450、imsdk 737 个类都还在，说明砍掉的是播放器、不是通话。CI 里
`libdownloadproxy` / `libtpcore-master`（Professional 独有）出现即判红。

到这里，单靠「删死东西」能删的删完了，剩下的每条路都要拿东西换。
`.so` 改压缩（`jniLibs.useLegacyPackaging=true`，实测 zlib level6
能把 39.9M 压到 16.8M，APK 57.2MB → 33.0MB，下载少 24.2MB／42%；代价是设备上「APK 31.5MiB +
解出来的 39.9MiB」两份，比现在的 54.6MiB 净多 16.8MiB，而且失去直接 mmap）；
砍音视频通话和直播（`libliteavsdk` 7.85 + `libtuikitengineroom` 2.75 + `libtxffmpeg` 1.99 +
`libtxsoundtouch` 0.23 + calls_uikit 的铃声等 assets 2.20，约 15.0M）；
关掉表情面板的 QQ/腾讯官方两组表情（`useQQStickerPackage`/`useTencentCloudChatStickerPackage`，2.5M）。
这 2.5M 不是把两个开关拨到 false 就能省的：插件的 `assets/custom_face_resource/{4349,tcc1}` 写在它自己的
pubspec 里，`flutter build` 按依赖图无条件打进包，运行时开关只管显示。要拿回来只能把插件 vendor 进来删资源
（tcc1 一组就占包内 2.24M，4349 只有 0.24M）；这两组已经是 160/56 像素的小图，
改成 lossless webp 也只省 0.67M，不值得为它维护一个 fork。
另有上游「联系我们」那页：两张二维码转 webp 后 0.26M、`qq/wechat/telegram/whatsapp` 四个图标 0.06M，
删不删看还要不要那个入口。厂商推送也能砍：dex 里 14,069 个类有 2,286 个（16.2%）是推送 SDK
（hms 738 / xiaomi 671 / firebase 432 / vivo 249 / honor 100 / meizu 60 / oppo 32），
只留自己那一路约省 0.3-0.5M，代价是别的品牌收不到离线推送。

Android 包是混淆过的：release 开了 R8（`minifyEnabled true`），CI 用 `--obfuscate --split-debug-info`。
反混淆要用的 `mapping.txt` 和 `app.android-arm64.symbols` 存成 `symbols-android-arm64` 这个 artifact，
它**不进公开 Release**（「发 Release」job 按名字逐个下载三个包体），否则任何人都能还原你的崩溃栈。
`proguard-rules.pro` 里 `com.tencent.** { *; }` 的整包 keep 是故意留的：SDK 走 JNI 和 Gson 反射，
收窄它省下的体积不值得换来只在真机上复现的崩溃。

凭据不再走 Secrets：[.github/actions/im-credentials](.github/actions/im-credentials) 只做一件事——把入库的 `lib/im_credentials.example.dart` 拷成 `lib/im_credentials.dart`。
仓库里原来配的 `IM_SDK_APP_ID` / `IM_SECRET_KEY` 已经不参与构建，留着没用，可以自行删掉。

## 我们自己的功能

- **自动登录**：7 天内的会话免登录，开关在登录页；退出登录会清干净本地登录态（`lib/utils/auto_login_store.dart`），不会被自动重登顶回去。
- **大文件分片**：超过 100MB 的单文件自动切片发送，界面上仍然只有一条文件气泡，分片气泡不渲染，收齐后自动合并（`lib/utils/file_transfer/`）。分片元数据放在消息的 `cloudCustomData` 里，不占文件名。
- **自有加密**：算法层在 [lib/utils/secure_channel/secure_channel.dart](lib/utils/secure_channel/secure_channel.dart)，X25519 临时密钥协商 + HKDF-SHA256 + ChaCha20-Poly1305，单测覆盖越权/篡改/截断。尚未接到消息与文件收发路径上——uikit 没有发送前的钩子（`ChatLifeCycle.messageWillSend` 是注释掉的），且 `MessageService` 在 `setupServiceLocator()` 里就被抓进各 ViewModel 的 final 字段，事后重新注册看不见。接入前要先解决身份私钥的落盘方式，以及三处明文泄漏：`offlinePushInfo.desc`、引用回复写进 `cloudCustomData` 的原文、发给腾讯的翻译请求。

## iOS / macOS 构建注意事项

见 [BUILD.md](BUILD.md)（CocoaPods 仓库过期、`pod deintegrate` 重装等）。
