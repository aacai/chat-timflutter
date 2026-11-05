import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_file_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_file_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_download_progress.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_download_progress.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/permission.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_file_icon.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

/// 自绘文件消息气泡。
///
/// uikit 自带的 TIMUIKitFileElem 的底色（weakBackgroundColor）与文件名文字
/// （darkTextColor）取自语义不同的主题字段，明暗两种模式下对比度都会失衡，
/// 文件名经常浅到看不清。这里改为应用侧自绘：文字只用应用主题的主/次文字色，
/// 明暗模式与小屏 / 桌面大屏都保持可读；下载与打开行为与 uikit 保持一致。
class FileMessageBubble extends StatefulWidget {
  final V2TimMessage message;

  const FileMessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  State<FileMessageBubble> createState() => _FileMessageBubbleState();
}

class _FileMessageBubbleState extends State<FileMessageBubble> {
  static const double _mobileWidth = 170;
  static const double _desktopWidth = 260;

  int _progress = 0;
  bool _downloading = false;
  String _localPath = "";
  V2TimAdvancedMsgListener? _listener;

  V2TimFileElem get _fileElem => widget.message.fileElem!;

  String get _fileName => _fileElem.fileName ?? "";

  String? get _fileFormat {
    final parts = _fileName.split(".");
    if (parts.length > 1 && parts.last.isNotEmpty) return parts.last;
    return null;
  }

  bool get _isFromSelf => widget.message.isSelf ?? true;

  @override
  void initState() {
    super.initState();
    _checkLocalFile();
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  bool _isDarkTheme(BuildContext context) {
    final themeData = Provider.of<DefaultThemeData>(context, listen: false);
    return themeData.themeMode == ThemeMode.dark ||
        (themeData.themeMode == ThemeMode.system && DefTheme.isPlatformDark);
  }

  Future<void> _checkLocalFile() async {
    if (PlatformUtils().isWeb) return;
    final path = _fileElem.localUrl ?? _fileElem.path ?? "";
    if (path.isNotEmpty && File(path).existsSync()) {
      if (!mounted) return;
      setState(() {
        _localPath = path;
        _progress = 100;
      });
    }
  }

  Future<void> _handleTap() async {
    try {
      if (PlatformUtils().isWeb) {
        await _downloadWebFile();
        return;
      }
      if (_localPath.isNotEmpty) {
        await _openLocalFile();
        return;
      }
      if (_downloading) {
        ToastUtils.toast(TIM_t("正在下载中"));
        return;
      }
      await _startDownload();
    } catch (e) {
      ToastUtils.toast(TIM_t("文件处理异常") + " $e");
    }
  }

  Future<void> _startDownload() async {
    final msgID = widget.message.msgID ?? "";
    if (msgID.isEmpty) return;

    // 与 uikit 行为一致：Android 12 及以下下载前检查存储权限。
    if (PlatformUtils().isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 33) {
        final ok = await Permissions.checkPermission(
            context, Permission.storage.value, null, false);
        if (!ok) return;
      }
    }

    _addListener();
    if (mounted) setState(() => _downloading = true);
    await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .downloadMessage(
          msgID: msgID,
          messageType: 6,
          imageType: 0,
          isSnapshot: false,
        );
  }

  void _addListener() {
    if (_listener != null) return;
    _listener = V2TimAdvancedMsgListener(
      onMessageDownloadProgressCallback:
          (V2TimMessageDownloadProgress progress) async {
        if (progress.msgID != widget.message.msgID) return;
        if (progress.errorCode != 0) {
          if (mounted) setState(() => _downloading = false);
          ToastUtils.toast(TIM_t("下载失败"));
          return;
        }
        if (progress.isFinish) {
          if (mounted) {
            setState(() {
              _progress = 100;
              _downloading = false;
              _localPath = progress.path;
            });
          }
          _removeListener();
          return;
        }
        if (progress.totalSize > 0 && mounted) {
          final p = (progress.currentSize / progress.totalSize * 100).floor();
          if (p > _progress) setState(() => _progress = p);
        }
      },
    );
    TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .addAdvancedMsgListener(listener: _listener!);
  }

  void _removeListener() {
    if (_listener != null) {
      TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .removeAdvancedMsgListener(listener: _listener!);
      _listener = null;
    }
  }

  Future<void> _openLocalFile() async {
    if (_localPath.isEmpty) return;
    final f = File(_localPath);
    if (await f.length() == 0 || widget.message.status == 3) {
      ToastUtils.toast(TIM_t("不支持 0KB 文件的传输"));
      return;
    }
    try {
      if (PlatformUtils().isDesktop && !PlatformUtils().isWindows) {
        await launchUrl(Uri.file(_localPath));
      } else {
        await OpenFile.open(_localPath);
      }
    } catch (e) {
      await OpenFile.open(_localPath);
    }
  }

  Future<void> _downloadWebFile() async {
    final url = _fileElem.path ?? "";
    if (url.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      final anchor = html.document.createElement('a') as html.AnchorElement;
      final blob = html.Blob([response.bodyBytes]);
      anchor.href = html.Url.createObjectUrlFromBlob(blob);
      anchor.download = _fileName;
      anchor.click();
    } catch (e) {
      html.AnchorElement(href: url)
        ..setAttribute("download", _fileName)
        ..setAttribute("target", '_blank')
        ..style.display = "none"
        ..click();
    }
  }

  String _formatSize(int? fileSize) {
    if (fileSize == null) return "";
    if (fileSize < 1024) {
      return "$fileSize" "B";
    } else if (fileSize < 1024 * 1024) {
      return (fileSize / 1024).toStringAsFixed(2) + "KB";
    } else if (fileSize < 1024 * 1024 * 1024) {
      return (fileSize / 1024 / 1024).toStringAsFixed(2) + "MB";
    }
    return (fileSize / 1024 / 1024 / 1024).toStringAsFixed(2) + "GB";
  }

  BorderRadius _bubbleRadius(bool isSelf) {
    return isSelf
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(2),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10))
        : const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10));
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = _isDarkTheme(context);
    final isDesktop =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final bubbleWidth = isDesktop ? _desktopWidth : _mobileWidth;
    final background = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE5E6E9);
    final progressColor = (appTheme.primaryColor ?? const Color(0xFF147AFF))
        .withValues(alpha: 0.4);
    final downloading = _progress > 0 && _progress < 100;

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: bubbleWidth,
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: borderColor),
          borderRadius: _bubbleRadius(_isFromSelf),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (downloading)
              LinearProgressIndicator(
                minHeight: 72,
                value: _progress / 100,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(progressColor),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: appTheme.darkTextColor,
                            fontSize: 16,
                          ),
                        ),
                        if (_fileElem.fileSize != null)
                          Text(
                            _formatSize(_fileElem.fileSize),
                            style: TextStyle(
                              fontSize: 14,
                              color: appTheme.weakTextColor,
                            ),
                          ),
                        if (downloading)
                          Text(
                            "$_progress%",
                            style: TextStyle(
                                fontSize: 12, color: progressColor),
                          ),
                      ],
                    ),
                  ),
                  TIMUIKitFileIcon(fileFormat: _fileFormat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
