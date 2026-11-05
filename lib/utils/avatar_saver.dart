import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

class AvatarSaveResult {
  final bool success;
  final String? path;

  const AvatarSaveResult(this.success, this.path);
}

/// 把网络头像保存到本地：桌面写「下载」目录、移动端写相册、Web 触发浏览器下载；
/// 任一环节失败都退回到应用文档目录，保证至少有一个本地文件可用。
class AvatarSaver {
  static Future<AvatarSaveResult> save(String url) async {
    if (url.isEmpty) return const AvatarSaveResult(false, null);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return const AvatarSaveResult(false, null);
      }
      final bytes = response.bodyBytes;
      final name = _fileName(url, response.headers['content-type']);

      if (kIsWeb) {
        final anchor = html.AnchorElement(
            href: html.Url.createObjectUrlFromBlob(html.Blob([bytes])))
          ..setAttribute("download", name)
          ..style.display = "none";
        anchor.click();
        return const AvatarSaveResult(true, null);
      }

      if (Platform.isAndroid || Platform.isIOS) {
        try {
          final result =
              await ImageGallerySaverPlus.saveImage(bytes, name: name);
          if (result is Map && result['isSuccess'] == true) {
            return AvatarSaveResult(true, result['filePath']?.toString());
          }
        } catch (_) {
          // 相册权限被拒绝或插件不支持时，退回本地文件。
        }
      }

      Directory? dir;
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        dir = await getDownloadsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(bytes, flush: true);
      return AvatarSaveResult(true, file.path);
    } catch (_) {
      return const AvatarSaveResult(false, null);
    }
  }

  static String _fileName(String url, String? contentType) {
    String ext = "png";
    final type = (contentType ?? "").toLowerCase();
    if (type.contains("jpeg") || type.contains("jpg")) {
      ext = "jpg";
    } else if (type.contains("webp")) {
      ext = "webp";
    } else if (type.contains("gif")) {
      ext = "gif";
    } else {
      final path = url.toLowerCase().split('?').first;
      for (final candidate in ["jpg", "jpeg", "png", "webp", "gif"]) {
        if (path.endsWith(".$candidate")) {
          ext = candidate == "jpeg" ? "jpg" : candidate;
          break;
        }
      }
    }
    return "avatar_${DateTime.now().millisecondsSinceEpoch}.$ext";
  }
}
