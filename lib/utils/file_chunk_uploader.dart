import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// 文件分片信息
class FileChunkInfo {
  final String fileId; // 整个文件的唯一 ID
  final String fileName; // 文件名
  final int totalChunks; // 总分片数
  final int chunkIndex; // 当前分片索引 (0-based)
  final int chunkSize; // 分片大小
  final int fileSize; // 文件总大小
  final String chunkMd5; // 分片 MD5（用于校验）

  FileChunkInfo({
    required this.fileId,
    required this.fileName,
    required this.totalChunks,
    required this.chunkIndex,
    required this.chunkSize,
    required this.fileSize,
    required this.chunkMd5,
  });

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'fileName': fileName,
      'totalChunks': totalChunks,
      'chunkIndex': chunkIndex,
      'chunkSize': chunkSize,
      'fileSize': fileSize,
      'chunkMd5': chunkMd5,
    };
  }

  static FileChunkInfo fromJson(Map<String, dynamic> json) {
    return FileChunkInfo(
      fileId: json['fileId'] as String,
      fileName: json['fileName'] as String,
      totalChunks: json['totalChunks'] as int,
      chunkIndex: json['chunkIndex'] as int,
      chunkSize: json['chunkSize'] as int,
      fileSize: json['fileSize'] as int,
      chunkMd5: json['chunkMd5'] as String,
    );
  }

  String toJsonString() {
    return 'fileId|$fileName|$totalChunks|$chunkIndex|$chunkSize|$fileSize|$chunkMd5';
  }

  static FileChunkInfo fromJsonString(String str) {
    final parts = str.split('|');
    return FileChunkInfo(
      fileId: parts[0],
      fileName: parts[1],
      totalChunks: int.parse(parts[2]),
      chunkIndex: int.parse(parts[3]),
      chunkSize: int.parse(parts[4]),
      fileSize: int.parse(parts[5]),
      chunkMd5: parts[6],
    );
  }
}

/// 文件元数据（用于接收端）
class FileMetadata {
  final String fileId;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final String senderId;
  final DateTime createdAt;

  FileMetadata({
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.senderId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'fileName': fileName,
      'fileSize': fileSize,
      'totalChunks': totalChunks,
      'senderId': senderId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static FileMetadata fromJson(Map<String, dynamic> json) {
    return FileMetadata(
      fileId: json['fileId'] as String,
      fileName: json['fileName'] as String,
      fileSize: json['fileSize'] as int,
      totalChunks: json['totalChunks'] as int,
      senderId: json['senderId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 文件分片上传器
class FileChunkUploader {
  // 分片大小（95MB，预留余量避免超限）
  static const int CHUNK_SIZE = 95 * 1024 * 1024;

  final Uuid _uuid = const Uuid();

  /// 分割文件为多个分片
  /// 返回：分片文件路径列表
  Future<List<String>> splitFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', filePath);
    }

    final fileSize = await file.length();
    final fileName = path.basename(filePath);
    final totalChunks = (fileSize / CHUNK_SIZE).ceil();
    final chunkPaths = <String>[];

    // 获取临时目录
    final tempDir = await _getChunkTempDir();

    // 生成文件唯一 ID
    final fileId = await generateFileId(filePath);

    // 读取文件并分割
    final randomAccessFile = await file.open();
    try {
      for (int i = 0; i < totalChunks; i++) {
        final offset = i * CHUNK_SIZE;
        final size = (i < totalChunks - 1) ? CHUNK_SIZE : (fileSize - offset);

        // 读取分片数据
        final buffer = Uint8List(size);
        await randomAccessFile.setPosition(offset);
        await randomAccessFile.readInto(buffer);

        // 生成分片文件
        final chunkFileName = '${fileId}_chunk_$i.tmp';
        final chunkPath = path.join(tempDir.path, chunkFileName);
        final chunkFile = File(chunkPath);

        // 写入分片文件
        await chunkFile.writeAsBytes(buffer);
        chunkPaths.add(chunkPath);
      }
      
      // 保存元数据文件（供接收端扫描使用）
      final metaFileName = '${fileId}_metadata.txt';
      final metaFilePath = path.join(tempDir.path, metaFileName);
      final metaContent = '$fileName|$fileSize|$totalChunks';
      await File(metaFilePath).writeAsString(metaContent);
    } finally {
      await randomAccessFile.close();
    }

    return chunkPaths;
  }

  /// 生成文件唯一 ID（基于文件路径和时间的 MD5）
  Future<String> generateFileId(String filePath) async {
    final fileName = path.basename(filePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final uniqueString = '$fileName$timestamp${_uuid.v4()}';

    final bytes = utf8.encode(uniqueString);
    final md5Digest = md5.convert(bytes);
    return md5Digest.toString();
  }

  /// 生成文件 MD5
  Future<String> generateFileMd5(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', filePath);
    }

    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 生成分片 MD5
  Future<String> generateChunkMd5(String chunkPath) async {
    return await generateFileMd5(chunkPath);
  }

  /// 获取分片信息
  Future<FileChunkInfo> getChunkInfo({
    required String fileId,
    required String filePath,
    required int chunkIndex,
    required int totalChunks,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();
    final fileName = path.basename(filePath);

    final offset = chunkIndex * CHUNK_SIZE;
    final size = (chunkIndex < totalChunks - 1) ? CHUNK_SIZE : (fileSize - offset);

    // 创建临时分片文件用于计算 MD5
    final tempDir = await _getChunkTempDir();
    final chunkFileName = '${fileId}_chunk_$chunkIndex.tmp';
    final chunkPath = path.join(tempDir.path, chunkFileName);

    String chunkMd5;
    if (await File(chunkPath).exists()) {
      // 如果分片已存在，直接计算 MD5
      chunkMd5 = await generateChunkMd5(chunkPath);
    } else {
      // 否则需要创建分片
      final randomAccessFile = await file.open();
      try {
        final buffer = Uint8List(size);
        await randomAccessFile.setPosition(offset);
        await randomAccessFile.readInto(buffer);

        final chunkFile = File(chunkPath);
        await chunkFile.writeAsBytes(buffer);
        chunkMd5 = await generateChunkMd5(chunkPath);
      } finally {
        await randomAccessFile.close();
      }
    }

    return FileChunkInfo(
      fileId: fileId,
      fileName: fileName,
      totalChunks: totalChunks,
      chunkIndex: chunkIndex,
      chunkSize: size,
      fileSize: fileSize,
      chunkMd5: chunkMd5,
    );
  }

  /// 获取临时目录
  Future<Directory> _getChunkTempDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = Directory(path.join(appDir.path, 'chunk_temp'));

    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    return tempDir;
  }

  /// 清理临时分片文件
  Future<void> cleanupTempFiles(String fileId) async {
    try {
      final tempDir = await _getChunkTempDir();
      final files = tempDir.listSync();

      for (final entity in files) {
        if (entity is File && entity.path.contains(fileId)) {
          await entity.delete();
        }
      }
    } catch (e) {
      // 清理失败不影响主流程
      print('清理临时文件失败：$e');
    }
  }

  /// 清理所有临时文件
  Future<void> cleanupAllTempFiles() async {
    try {
      final tempDir = await _getChunkTempDir();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      print('清理所有临时文件失败：$e');
    }
  }
}
