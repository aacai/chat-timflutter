import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';

import 'chunk_codec.dart';

/// 一次大文件传输的本地记录：发送端记源文件，接收端记合并结果。
class TransferRecord {
  final String fileId;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final String localPath;

  const TransferRecord({
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.localPath,
  });

  Map<String, dynamic> toJson() => {
        "fid": fileId,
        "name": fileName,
        "size": fileSize,
        "total": totalChunks,
        "path": localPath,
      };

  static TransferRecord? fromJson(dynamic json) {
    if (json is! Map || json["fid"] is! String || json["path"] is! String) {
      return null;
    }
    return TransferRecord(
      fileId: json["fid"] as String,
      fileName: json["name"] as String? ?? "",
      fileSize: (json["size"] as num?)?.toInt() ?? 0,
      totalChunks: (json["total"] as num?)?.toInt() ?? 0,
      localPath: json["path"] as String,
    );
  }
}

/// 大文件分片传输的编排：发送端切片逐片发送，接收端补齐分片后合并。
///
/// 分片消息对 UI 不可见（index != 0 全隐藏），只留第 0 片当门面：气泡上的文件名
/// 和大小都是整个文件的，合并完把本地路径指向合并结果，看起来就是一条普通文件消息。
class FileTransferService {
  FileTransferService._();

  static final FileTransferService instance = FileTransferService._();

  /// 与 UIKit 的文件上限保持一致，超过它才分片。
  static const int singleFileLimitBytes = 100 * 1024 * 1024;

  final Map<String, _PendingTransfer> _pending = {};
  final Map<String, TransferRecord> _records = {};

  TransferRecord? recordOf(String fileId) => _records[fileId];

  /// 分片与索引都放在应用私有目录，卸载即清。
  Future<Directory>? _workDirCached;

  Future<Directory> _workDir() => _workDirCached ??= getApplicationSupportDirectory().then((support) {
        final dir = Directory(p.join(support.path, "file_transfer"));
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return dir;
      });

  Future<File> _indexFile() async => File(p.join((await _workDir()).path, "index.json"));

  /// 恢复历史传输记录，App 启动时调用一次；重启后已合并的文件仍可被气泡指向。
  Future<void> restore() async {
    try {
      final index = await _indexFile();
      if (!await index.exists()) {
        return;
      }
      final list = jsonDecode(await index.readAsString());
      if (list is List) {
        for (final item in list) {
          final record = TransferRecord.fromJson(item);
          if (record != null) {
            _records[record.fileId] = record;
          }
        }
      }
    } catch (e) {
      debugPrint("分片传输索引读取失败：$e");
    }
  }

  Future<void> _persist() async {
    try {
      await (await _indexFile()).writeAsString(jsonEncode(_records.values.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint("分片传输索引写入失败：$e");
    }
  }

  /// 除第 0 片以外的分片不参与渲染，UI 上就看不到一堆 part 气泡。
  static bool shouldHide(String? cloudCustomData) {
    final header = ChunkHeader.decode(cloudCustomData);
    return header != null && header.index != 0;
  }

  /// 把第 0 片打扮成完整文件：显示整体大小，本地路径指向源文件或合并结果。
  void decorate(V2TimMessage message) {
    final header = ChunkHeader.decode(message.cloudCustomData);
    if (header == null || header.index != 0) {
      return;
    }
    message.fileElem?.fileSize = header.fileSize;
    message.fileElem?.fileName = header.fileName;
    final record = _records[header.fileId];
    if (record != null && File(record.localPath).existsSync()) {
      message.fileElem?.path = record.localPath;
      message.fileElem?.localUrl = record.localPath;
    }
  }

  /// 统一的文件发送入口：未超限按普通文件发，超限切片逐片发，界面看到的都是同一条文件气泡。
  Future<void> send({
    required TIMUIKitChatController controller,
    required String sourcePath,
  }) async {
    final fileSize = await File(sourcePath).length();
    if (fileSize == 0) {
      throw ArgumentError("不支持 0KB 文件的传输");
    }
    final fileName = p.basename(sourcePath);
    if (fileSize < singleFileLimitBytes) {
      await _sendPart(
        controller: controller,
        partPath: sourcePath,
        fileName: fileName,
        header: null,
      );
      return;
    }

    final fileId = ChunkCodec.newFileId(fileName, fileSize);
    final dir = await _workDir();
    final parts = await ChunkCodec.split(
      sourcePath: sourcePath,
      directory: dir.path,
      fileId: fileId,
    );
    try {
      for (final part in parts) {
        await _sendPart(
          controller: controller,
          partPath: part.path,
          fileName: fileName,
          header: ChunkHeader(
            fileId: fileId,
            fileName: fileName,
            fileSize: fileSize,
            totalChunks: parts.length,
            index: part.index,
            chunkSize: part.size,
            chunkMd5: part.md5,
          ),
        );
      }
      _records[fileId] = TransferRecord(
        fileId: fileId,
        fileName: fileName,
        fileSize: fileSize,
        totalChunks: parts.length,
        localPath: sourcePath,
      );
      await _persist();
    } finally {
      await ChunkCodec.deleteChunks(parts.map((e) => e.path));
    }
  }

  /// [header] 为空就是普通文件；非空时把气泡伪装成整个文件，并且只有第 0 片计入未读。
  Future<void> _sendPart({
    required TIMUIKitChatController controller,
    required String partPath,
    required String fileName,
    ChunkHeader? header,
  }) async {
    final created = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .createFileMessage(filePath: partPath, fileName: fileName);
    final messageInfo = created.data?.messageInfo;
    if (messageInfo == null) {
      throw StateError("创建文件消息失败：${created.code} ${created.desc}");
    }
    if (header != null) {
      messageInfo.fileElem?.fileSize = header.fileSize;
    }
    final res = await controller.sendMessage(
      messageInfo: messageInfo,
      cloudCustomData: header?.encode(),
      isExcludedFromUnreadCount: header != null && header.index != 0,
    );
    if (res == null || res.code != 0) {
      throw StateError("文件发送失败：${res?.desc ?? "无返回"}");
    }
  }

  /// 收到（或从历史里读到）一条分片消息时调用；补齐后自动合并。
  Future<void> onChunkMessage(V2TimMessage message) async {
    final header = ChunkHeader.decode(message.cloudCustomData);
    if (header == null || header.totalChunks <= 1 || header.index < 0) {
      return;
    }
    // 已经有结果（自己发的、或已经合并完的）就不要再拉一遍分片。
    if (_records.containsKey(header.fileId)) {
      return;
    }
    final transfer = _pending.putIfAbsent(header.fileId, () => _PendingTransfer(header));
    transfer.headers[header.index] = header;
    if (transfer.paths.containsKey(header.index)) {
      return;
    }

    final local = _localPathOf(message);
    if (local != null && await File(local).length() == header.chunkSize) {
      transfer.paths[header.index] = local;
    } else {
      final downloaded = await _download(message, header);
      if (downloaded == null) {
        return;
      }
      transfer.paths[header.index] = downloaded;
    }
    await _tryMerge(transfer);
  }

  String? _localPathOf(V2TimMessage message) {
    final path = message.fileElem?.path;
    final localUrl = message.fileElem?.localUrl;
    for (final candidate in [path, localUrl]) {
      if (candidate != null && candidate.isNotEmpty && File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  Future<String?> _download(V2TimMessage message, ChunkHeader header) async {
    final msgID = message.msgID;
    if (msgID == null || msgID.isEmpty) {
      return null;
    }
    final dir = await _workDir();
    final target = p.join(dir.path, ChunkCodec.chunkFileName(header.fileId, header.index));
    final targetFile = File(target);
    if (await targetFile.exists()) {
      // 底层遇到同名文件会直接回成功但不回调，坏片必须先删再下。
      if (await targetFile.length() == header.chunkSize) {
        return target;
      }
      await targetFile.delete();
    }
    final completer = Completer<String?>();
    try {
      final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().downloadMessage(
            msgID: msgID,
            messageType: MessageElemType.V2TIM_ELEM_TYPE_FILE,
            imageType: 0,
            isSnapshot: false,
            downloadPath: target,
            onDownloadFinished: (finished) {
              final path = _localPathOf(finished) ?? target;
              if (!completer.isCompleted) {
                completer.complete(File(path).existsSync() ? path : target);
              }
            },
          );
      if (res.code != 0 && !completer.isCompleted) {
        debugPrint("分片下载失败：${res.code} ${res.desc}");
        completer.complete(null);
      }
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      debugPrint("分片下载异常：$e");
    }
    return completer.future.timeout(
      const Duration(minutes: 30),
      onTimeout: () => targetFile.existsSync() ? target : null,
    );
  }

  Future<void> _tryMerge(_PendingTransfer transfer) async {
    if (transfer.merging || transfer.headers.length < transfer.totalChunks) {
      return;
    }
    final ordered = List<ChunkHeader>.generate(transfer.totalChunks, (i) => transfer.headers[i]!);
    if (transfer.paths.length < transfer.totalChunks) {
      return;
    }
    transfer.merging = true;
    try {
      final dir = await _workDir();
      final destination = _uniqueDestination(dir.path, transfer.fileName);
      await ChunkCodec.merge(
        expected: ordered,
        chunkPathByIndex: transfer.paths,
        destinationPath: destination,
      );
      _records[transfer.fileId] = TransferRecord(
        fileId: transfer.fileId,
        fileName: transfer.fileName,
        fileSize: ordered.first.fileSize,
        totalChunks: transfer.totalChunks,
        localPath: destination,
      );
      await _persist();
      await ChunkCodec.deleteChunks(transfer.paths.values);
      _pending.remove(transfer.fileId);
      onCompleted?.call(transfer.fileId, destination, transfer.fileName);
    } catch (e) {
      transfer.merging = false;
      onFailed?.call(transfer.fileId, "$e");
      debugPrint("大文件合并失败：$e");
    }
  }

  String _uniqueDestination(String directory, String fileName) {
    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    var candidate = p.join(directory, fileName);
    var i = 1;
    while (File(candidate).existsSync()) {
      candidate = p.join(directory, "$base($i)$ext");
      i++;
    }
    return candidate;
  }

  /// 合并完成 / 失败的回调，由界面层挂 Toast。
  void Function(String fileId, String path, String fileName)? onCompleted;
  void Function(String fileId, String error)? onFailed;
}

class _PendingTransfer {
  _PendingTransfer(ChunkHeader first)
      : fileName = first.fileName,
        totalChunks = first.totalChunks,
        fileId = first.fileId;

  final String fileId;
  final String fileName;
  final int totalChunks;
  final Map<int, ChunkHeader> headers = {};
  final Map<int, String> paths = {};
  bool merging = false;
}
