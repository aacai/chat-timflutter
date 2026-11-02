import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// 分片消息的 cloudCustomData 载荷版本，接收端据此判断能不能处理。
const int chunkProtocolVersion = 1;

/// 单个分片的元信息，随消息的 cloudCustomData 一起下发，不放进文件名。
class ChunkHeader {
  final String fileId;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final int index;
  final int chunkSize;
  final String chunkMd5;

  /// 该分片是否经过端到端加密（字节已被加密信封替换）。
  final bool encrypted;

  const ChunkHeader({
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.index,
    required this.chunkSize,
    required this.chunkMd5,
    this.encrypted = false,
  });

  Map<String, dynamic> _toJson() => {
        "v": chunkProtocolVersion,
        "fid": fileId,
        "name": fileName,
        "size": fileSize,
        "total": totalChunks,
        "idx": index,
        "csize": chunkSize,
        "md5": chunkMd5,
        "enc": encrypted,
      };

  String encode() => jsonEncode(_toJson());

  /// 只有我们自己的分片消息才带这个标记，其它消息一律返回 null，交回给正常渲染。
  static ChunkHeader? decode(String? cloudCustomData) {
    if (cloudCustomData == null || cloudCustomData.isEmpty || !cloudCustomData.startsWith("{")) {
      return null;
    }
    try {
      final json = jsonDecode(cloudCustomData);
      if (json is! Map || json["v"] != chunkProtocolVersion || json["fid"] is! String) {
        return null;
      }
      return ChunkHeader(
        fileId: json["fid"] as String,
        fileName: json["name"] as String? ?? "",
        fileSize: (json["size"] as num?)?.toInt() ?? 0,
        totalChunks: (json["total"] as num?)?.toInt() ?? 0,
        index: (json["idx"] as num?)?.toInt() ?? -1,
        chunkSize: (json["csize"] as num?)?.toInt() ?? 0,
        chunkMd5: json["md5"] as String? ?? "",
        encrypted: json["enc"] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 切分出来的一个分片。
class ChunkArtifact {
  final int index;
  final String path;
  final int size;
  final String md5;

  const ChunkArtifact({
    required this.index,
    required this.path,
    required this.size,
    required this.md5,
  });
}

/// 大文件分片的纯文件算法，不依赖 IM，可单独测试。
///
/// 读写全部走 64KB 缓冲的流式拷贝，避免把整片读进内存（旧实现一片 95MB 直接 Uint8List 载入）。
class ChunkCodec {
  static const int maxChunkBytes = 90 * 1024 * 1024;
  static const int _copyBufferSize = 64 * 1024;

  static String chunkFileName(String fileId, int index) => "$fileId.part$index.chunk";

  static Future<String> md5OfFile(String path) {
    final digest = ChunkDigest();
    return File(path).openRead().forEach(digest.add).then((_) => digest.finish());
  }

  /// 生成一个不会撞车的传输 ID。
  static String newFileId(String fileName, int fileSize) {
    return md5.convert(utf8.encode("$fileName$fileSize${Uuid().v4()}")).toString();
  }

  /// 把源文件切成 maxChunkBytes 大小的分片，落到 [directory]，返回每片的路径 / 大小 / MD5。
  static Future<List<ChunkArtifact>> split({
    required String sourcePath,
    required String directory,
    required String fileId,
    int chunkBytes = maxChunkBytes,
  }) async {
    final source = File(sourcePath);
    final fileSize = await source.length();
    if (chunkBytes <= 0) {
      throw ArgumentError.value(chunkBytes, "chunkBytes", "必须大于 0");
    }
    final totalChunks = (fileSize / chunkBytes).ceil();
    final artifacts = <ChunkArtifact>[];
    final raf = await source.open();
    try {
      for (var i = 0; i < totalChunks; i++) {
        final offset = i * chunkBytes;
        final length = fileSize - offset < chunkBytes ? fileSize - offset : chunkBytes;
        final chunkPath = p.join(directory, chunkFileName(fileId, i));
        final digest = ChunkDigest();
        final out = File(chunkPath);
        final IOSink outSink = out.openWrite();
        try {
          await raf.setPosition(offset);
          var remaining = length;
          while (remaining > 0) {
            final buffer = await raf.read(remaining < _copyBufferSize ? remaining : _copyBufferSize);
            if (buffer.isEmpty) {
              throw FileSystemException("源文件意外结束", sourcePath);
            }
            remaining -= buffer.length;
            outSink.add(buffer);
            digest.add(buffer);
          }
        } finally {
          await outSink.close();
        }
        artifacts.add(ChunkArtifact(index: i, path: chunkPath, size: length, md5: digest.finish()));
      }
    } finally {
      await raf.close();
    }
    return artifacts;
  }

  /// 按 [expected] 里的顺序和大小合并分片并逐片校验 MD5，写临时文件再改名，避免留下半个文件。
  ///
  /// [encrypted] 为 true 时，[decrypt] 必须提供：每片先解密再拼接，最终大小对齐 [ChunkHeader.fileSize]。
  static Future<String> merge({
    required List<ChunkHeader> expected,
    required Map<int, String> chunkPathByIndex,
    required String destinationPath,
    bool encrypted = false,
    Future<Uint8List> Function(Uint8List)? decrypt,
  }) async {
    final totalBytes = expected.fold<int>(0, (sum, header) {
      final path = chunkPathByIndex[header.index];
      if (path == null) {
        throw StateError("缺少第 ${header.index} 片");
      }
      return sum + header.chunkSize;
    });
    final tempPath = "$destinationPath.partial";
    final out = File(tempPath);
    final sink = out.openWrite();
    try {
      for (final header in expected) {
        final path = chunkPathByIndex[header.index]!;
        final chunkFile = File(path);
        if (!await chunkFile.exists()) {
          throw FileSystemException("分片文件不存在", path);
        }
        if (encrypted) {
          if (decrypt == null) {
            throw StateError("加密分片缺少解密器");
          }
          final plain = await decrypt(await chunkFile.readAsBytes());
          sink.add(plain);
          continue;
        }
        if (await chunkFile.length() != header.chunkSize) {
          throw const FormatException("分片大小与元数据不符");
        }
        if (header.chunkMd5.isNotEmpty && await md5OfFile(path) != header.chunkMd5) {
          throw FormatException("第 ${header.index} 片 MD5 校验失败");
        }
        await sink.addStream(chunkFile.openRead());
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (encrypted) {
      if (await out.length() != (expected.first.fileSize)) {
        throw const FormatException("解密合并后大小与元数据不符");
      }
    } else if (totalBytes > 0 && await out.length() != totalBytes) {
      throw const FormatException("合并后大小与元数据不符");
    }
    final target = File(destinationPath);
    if (await target.exists()) {
      await target.delete();
    }
    await out.rename(destinationPath);
    return destinationPath;
  }

  static Future<void> deleteChunks(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        await File(path).delete();
      } catch (_) {
        // 分片已被清理过不该影响主流程
      }
    }
  }
}

/// 边读边算 MD5，不用把整个文件读进内存。
class ChunkDigest {
  final _collector = _DigestCollector();
  late final _input = md5.startChunkedConversion(_collector);

  void add(List<int> bytes) {
    _input.add(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
  }

  String finish() {
    _input.close();
    return _collector.digest.toString();
  }
}

class _DigestCollector implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
