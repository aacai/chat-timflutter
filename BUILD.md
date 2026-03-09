# iOS/macOS 构建注意事项

## CocoaPods 依赖问题

### 常见问题
- **错误**: `CocoaPods's specs repository is too out-of-date to satisfy dependencies`
- **错误**: `CocoaPods could not find compatible versions for pod "TXIMSDK_Plus_Mac"`

### 解决方案
```bash
# 1. 更新 CocoaPods 仓库
pod repo update

# 2. 清理旧的 CocoaPods 配置
cd ios && pod deintegrate
cd macos && pod deintegrate

# 3. 重新安装依赖
cd ios && pod install
cd macos && pod install

# 4. 如遇到特定依赖版本冲突
cd macos && pod update TXIMSDK_Plus_Mac
```

### 构建命令
```bash
# iOS 构建
flutter build ios

# macOS 构建
flutter build macos

# 运行应用
flutter run -d ios
flutter run -d macos
```

### 清理缓存
```bash
flutter clean
flutter pub get
cd ios && pod install
cd macos && pod install
```