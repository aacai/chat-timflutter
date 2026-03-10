import 'dart:io';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'file_chunk_uploader.dart';

/// 文件合并信息
class FileMergeInfo {
  final String fileId;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final int receivedChunks;
  final bool isComplete;

  FileMergeInfo({
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.receivedChunks,
    required this.isComplete,
  });
}

/// 文件分片接收合并器
class FileChunkAssembler {
  // 临时存储目录
  static const String tempDirName = 'chunk_temp';

  // 文件元数据缓存
  final Map<String, FileMetadata> _pendingFiles = {};

  // 分片缓存：fileId -> {chunkIndex: chunkPath}
  final Map<String, Map<int, String>> _fileChunks = {};

  // 已接收的文件 ID 集合（避免重复处理）
  final Set<String> _completedFiles = {};

  // 进度回调
  final Function(String fileId, double progress)? onProgress;

  // 完成回调 - 返回合并后的文件信息和需要删除的分片消息ID列表
  final Function(String fileId, String filePath, String fileName, List<String> msgIds)? onComplete;

  // 错误回调
  final Function(String fileId, String error)? onError;

  // 保存分片消息ID: fileId -> [msgId1, msgId2, ...]
  final Map<String, List<String>> _chunkMessageIds = {};

  FileChunkAssembler({
    this.onProgress,
    this.onComplete,
    this.onError,
  });

  /// 处理接收到的消息
  Future<void> onMessageReceived(V2TimMessage message) async {
    try {
      print('📥 收到消息: msgID=${message.id}, sender=${message.sender}, elemType=${message.elemType}');

      // 只处理文件消息
      if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_FILE) {
        print('不是文件消息，跳过');
        return;
      }

      final fileElem = message.fileElem;
      if (fileElem == null) {
        print('❌ 文件元素为空');
        return;
      }

      final fileName = fileElem.fileName ?? '';
      final filePath = fileElem.path;
      print('📎 文件名: $fileName, 路径: $filePath');
      
      // 判断是否是分片文件（文件名格式：chunk_index|metadata_json）
      if (!fileName.startsWith('chunk_')) {
        print('普通文件，不是分片，跳过');
        return;
      }

      print('✅ 检测到分片文件，开始处理');
      await _handleChunkMessage(message);
    } catch (e) {
      print('处理分片消息失败：$e');
      print(e.toString());
    }
  }

  /// 处理分片消息
  Future<void> _handleChunkMessage(V2TimMessage message) async {
    final fileElem = message.fileElem;
    if (fileElem == null) {
      print('❌ fileElem 为空');
      return;
    }

    final fileName = fileElem.fileName ?? '';
    final filePath = fileElem.path;

    print('🔍 _handleChunkMessage: fileName=$fileName, filePath=$filePath');

    if (filePath == null || filePath.isEmpty) {
      print('❌ 文件路径为空');
      return;
    }

    // 解析分片索引和元数据
    // 格式：chunk_index|fileId|originalFileName|totalChunks|fileSize|chunkIndex|chunkSize|chunkMd5
    final parts = fileName.split('|');
    print('📋 parts 解析: ${parts.length} 个部分, 内容: $parts');
    
    if (parts.length < 2) {
      print('⚠️ 格式不符合，尝试旧格式');
      // 旧格式，尝试从云自定义数据获取
      await _handleChunkWithCustomData(message, filePath);
      return;
    }

    try {
      final chunkIndex = int.parse(parts[0].replaceFirst('chunk_', ''));
      final fileId = parts[1];
      final originalFileName = parts[2];
      final totalChunks = int.parse(parts[3]);
      final fileSize = int.parse(parts[4]);

      print('📦 分片信息: chunkIndex=$chunkIndex, fileId=$fileId, fileName=$originalFileName, totalChunks=$totalChunks, fileSize=$fileSize');

      // 保存文件元数据
      if (!_pendingFiles.containsKey(fileId)) {
        print('📝 保存文件元数据');
        _pendingFiles[fileId] = FileMetadata(
          fileId: fileId,
          fileName: originalFileName,
          fileSize: fileSize,
          totalChunks: totalChunks,
          senderId: message.sender ?? '',
          createdAt: DateTime.now(),
        );
      }

      // 保存分片路径
      print('💾 保存分片: chunk_$chunkIndex -> $filePath');
      _fileChunks.putIfAbsent(fileId, () => {});
      _fileChunks[fileId]![chunkIndex] = filePath;

      // 保存分片消息ID
      final msgId = message.id;
      if (msgId != null) {
        _chunkMessageIds.putIfAbsent(fileId, () => []);
        if (!_chunkMessageIds[fileId]!.contains(msgId)) {
          _chunkMessageIds[fileId]!.add(msgId);
        }
        print('📝 保存分片消息ID: $msgId');
      }

      // 检查是否收齐全部分片
      final receivedChunks = _fileChunks[fileId]!.length;
      print('📊 已收分片: $receivedChunks / $totalChunks');
      
      // 通知进度
      if (onProgress != null) {
        final progress = receivedChunks / totalChunks;
        onProgress!(fileId, progress);
      }

      if (receivedChunks >= totalChunks) {
        print('🎉 分片收齐，开始合并!');
        // 收齐全部分片，开始合并
        await _mergeChunks(fileId);
      }
    } catch (e) {
      print('❌ 解析分片信息失败：$e');
      // 尝试使用自定义数据方式
      await _handleChunkWithCustomData(message, filePath);
    }
  }

  /// 处理带有自定义数据的分片消息（兼容方式）
  Future<void> _handleChunkWithCustomData(V2TimMessage message, String filePath) async {
    // 从云自定义数据或本地自定义数据中获取分片信息
    String? customData = message.cloudCustomData;
    if (customData == null || customData.isEmpty) {
      customData = message.localCustomData;
    }

    if (customData == null || customData.isEmpty) {
      print('未找到分片元数据');
      return;
    }

    try {
      final chunkInfo = FileChunkInfo.fromJsonString(customData);
      final fileId = chunkInfo.fileId;
      final chunkIndex = chunkInfo.chunkIndex;

      // 保存文件元数据
      if (!_pendingFiles.containsKey(fileId)) {
        _pendingFiles[fileId] = FileMetadata(
          fileId: fileId,
          fileName: chunkInfo.fileName,
          fileSize: chunkInfo.fileSize,
          totalChunks: chunkInfo.totalChunks,
          senderId: message.sender ?? '',
          createdAt: DateTime.now(),
        );
      }

      // 保存分片路径
      _fileChunks.putIfAbsent(fileId, () => {});
      _fileChunks[fileId]![chunkIndex] = filePath;

      // 检查是否收齐全部分片
      final receivedChunks = _fileChunks[fileId]!.length;

      // 通知进度
      if (onProgress != null) {
        final progress = receivedChunks / chunkInfo.totalChunks;
        onProgress!(fileId, progress);
      }

      if (receivedChunks >= chunkInfo.totalChunks) {
        await _mergeChunks(fileId);
      }
    } catch (e) {
      print('解析自定义数据失败：$e');
      if (onError != null) {
        onError!(message.id ?? '', '分片数据解析失败');
      }
    }
  }

  /// 合并分片
  Future<void> _mergeChunks(String fileId) async {
    print('🔄 _mergeChunks 开始执行, fileId=$fileId');
    
    try {
      // 检查是否已处理过
      if (_completedFiles.contains(fileId)) {
        print('⚠️ 文件已处理过，跳过');
        return;
      }

      final metadata = _pendingFiles[fileId];
      if (metadata == null) {
        print('❌ 元数据为空');
        return;
      }
      
      print('📄 元数据: fileName=${metadata.fileName}, fileSize=${metadata.fileSize}, totalChunks=${metadata.totalChunks}');

      final chunks = _fileChunks[fileId];
      if (chunks == null) {
        print('❌ 分片列表为空');
        return;
      }
      
      print('📦 分片数量: ${chunks.length}');

      // 验证分片完整性
      if (chunks.length < metadata.totalChunks) {
        print('❌ 分片不完整：${chunks.length}/${metadata.totalChunks}');
        return;
      }

      // 获取目标目录（下载目录）
      Directory downloadDir;
      if (kIsWeb) {
        downloadDir = await getApplicationDocumentsDirectory();
      } else if (Platform.isAndroid) {
        // Android 使用 Download 文件夹
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          // 备用方案
          downloadDir = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        // iOS 使用 Documents 文件夹
        downloadDir = await getApplicationDocumentsDirectory();
      } else {
        // 其他平台
        downloadDir = await getApplicationDocumentsDirectory();
      }
      print('📁 下载目录: ${downloadDir.path}');
      
      // 确定目标文件路径
      String targetPath = path.join(downloadDir.path, metadata.fileName);
      
      // 如果文件已存在，先删除
      final existingFile = File(targetPath);
      if (await existingFile.exists()) {
        print('🗑️ 删除已存在的文件: $targetPath');
        try {
          //有时本来有文件，也说没文件
          await existingFile.delete();
        } catch (e) {
        }
      }
      
      print('📍 目标文件路径: $targetPath');
      final targetFile = File(targetPath);

      // 创建目标文件
      print('📝 开始写入合并文件...');
      final sink = targetFile.openWrite();

      // 按顺序合并分片
      final sortedIndices = chunks.keys.toList()..sort();
      for (final index in sortedIndices) {
        final chunkPath = chunks[index]!;
        final chunkFile = File(chunkPath);

        if (await chunkFile.exists()) {
          print('➕ 合并分片 $index: $chunkPath');
          await sink.addStream(chunkFile.openRead());
        } else {
          print('❌ 分片文件不存在：$chunkPath');
          await sink.close();
          return;
        }
      }

      await sink.close();
      print('✅ 文件写入完成');

      // 标记为已完成
      _completedFiles.add(fileId);
      print('🎉 标记文件为已完成');

      // 获取需要删除的分片消息ID列表
      final msgIdsToDelete = _chunkMessageIds[fileId] ?? [];
      print('📋 需要删除的分片消息ID: $msgIdsToDelete');

      // 通知完成
      if (onComplete != null) {
        print('📢 触发完成回调');
        onComplete!(fileId, targetFile.path, metadata.fileName, msgIdsToDelete);
      }

      print('文件合并完成：${targetFile.path}');

      // TODO: 测试无误后删除分片临时文件
      // _cleanupTempFiles(fileId);
    } catch (e) {
      print('合并分片失败：$e');
      if (onError != null) {
        onError!(fileId, '文件合并失败：$e');
      }
    }
  }

  /// 清理临时分片文件
  void _cleanupTempFiles(String fileId) {
    try {
      final chunks = _fileChunks.remove(fileId);
      if (chunks != null) {
        for (final chunkPath in chunks.values) {
          try {
            final chunkFile = File(chunkPath);
            if (chunkFile.existsSync()) {
              chunkFile.deleteSync();
            }
          } catch (e) {
            print('删除分片失败：$e');
          }
        }
      }

      _pendingFiles.remove(fileId);
    } catch (e) {
      print('清理临时文件失败：$e');
    }
  }

  /// 获取待接收的文件列表
  List<FileMetadata> getPendingFiles() {
    return _pendingFiles.values.toList();
  }

  /// 扫描本地分片文件目录
  Future<void> scanLocalChunks() async {
    print('🔍 scanLocalChunks 开始扫描...');
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final chunkDir = Directory(path.join(appDir.path, tempDirName));
      final tempDir = await getTemporaryDirectory();
      
      // 扫描多个可能的目录
      final dirsToScan = [
        chunkDir,
        Directory(appDir.path), // 根目录
        tempDir,
      ];
      
      for (final dir in dirsToScan) {
        if (!await dir.exists()) continue;
        
        print('� 扫描目录: ${dir.path}');
        final entities = await dir.list().toList();
        
        for (final entity in entities) {
          if (entity is File) {
            final fileName = path.basename(entity.path);
            
            // 格式1: chunk_index|fileId|originalFileName|totalChunks|...
            if (fileName.startsWith('chunk_') && fileName.contains('|')) {
               await parseChunkFileV1(entity.path, fileName);
             }
            // 格式2: ${fileId}_chunk_${index}.tmp
            else if (fileName.contains('_chunk_') && fileName.endsWith('.tmp')) {
                await parseChunkFileV2(entity.path, fileName);
              }
          }
        }
      }
      
      print('🎉 扫描完成，待合并文件数: ${_pendingFiles.length}');
    } catch (e) {
      print('❌ 扫描本地分片失败：$e');
    }
  }

  /// 解析分片文件格式1: chunk_index|fileId|originalFileName|totalChunks|...
  Future<void> parseChunkFileV1(String filePath, String fileName) async {
    final parts = fileName.split('|');
    if (parts.length < 5) return;

    final chunkIndex = int.tryParse(parts[0].replaceFirst('chunk_', ''));
    if (chunkIndex == null) return;
    
    final fileId = parts[1];
    final originalFileName = parts[2];
    final totalChunks = int.parse(parts[3]);
    final fileSize = int.parse(parts[4]);

    _saveChunkInfo(fileId, originalFileName, fileSize, totalChunks, chunkIndex, filePath);
  }

  /// 解析分片文件格式2: ${fileId}_chunk_${index}.tmp
  Future<void> parseChunkFileV2(String filePath, String fileName) async {
    print("🔍 parseChunkFileV2: fileName=$fileName");
    
    // 格式: fileId_chunk_index.tmp
    final regex = RegExp(r'^(.+)_chunk_(\d+)\.tmp$');
    final match = regex.firstMatch(fileName);
    if (match == null) {
      print("❌ 正则不匹配");
      return;
    }

    final fileId = match.group(1)!;
    final chunkIndex = int.parse(match.group(2)!);
    print("📍 解析: fileId=$fileId, chunkIndex=$chunkIndex");
    
    // 尝试从其他文件获取元数据
    String fileName_ = 'unknown_file';
    int fileSize = 0;
    int totalChunks = 0;
    
    // 尝试查找元数据文件
    final dir = Directory(path.dirname(filePath));
    if (await dir.exists()) {
      final entities = await dir.list().toList();
      for (final e in entities) {
        final eName = path.basename(e.path);
        print("📄 检查文件: $eName");
        if (eName.contains('${fileId}_metadata')) {
          try {
            final content = await (e as File).readAsString();
            print("📄 元数据内容: $content");
            final meta = content.split('|');
            if (meta.length >= 3) {
              fileName_ = meta[0];
              fileSize = int.parse(meta[1]);
              totalChunks = int.parse(meta[2]);
              print("✅ 解析元数据成功: fileName=$fileName_");
              break;
            }
          } catch (e) {
            print("❌ 读取元数据失败: $e");
          }
        }
      }
    }
    
    // 如果没找到元数据，尝试从目录中统计分片数量
    if (totalChunks == 0) {
      int count = 0;
      final dir = Directory(path.dirname(filePath));
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        for (final e in entities) {
          if (e.path.contains(fileId) && e.path.contains('_chunk_')) {
            count++;
          }
        }
        totalChunks = count;
        print("📊 统计分片数: $totalChunks");
      }
    }
    
    _saveChunkInfo(fileId, fileName_, fileSize, totalChunks, chunkIndex, filePath);
  }

  void _saveChunkInfo(String fileId, String fileName, int fileSize, int totalChunks, int chunkIndex, String chunkPath) {
    print("📦 保存分片: fileId=$fileId, fileName=$fileName, chunkIndex=$chunkIndex, totalChunks=$totalChunks");
    
    // 保存或更新元数据
    final existingMeta = _pendingFiles[fileId];
    if (existingMeta == null) {
      _pendingFiles[fileId] = FileMetadata(
        fileId: fileId,
        fileName: fileName,
        fileSize: fileSize,
        totalChunks: totalChunks,
        senderId: 'local',
        createdAt: DateTime.now(),
      );
    } else {
      // 更新元数据（保留已有的文件名等信息）
      _pendingFiles[fileId] = FileMetadata(
        fileId: fileId,
        fileName: existingMeta.fileName.isNotEmpty && existingMeta.fileName != 'unknown_file' 
          ? existingMeta.fileName : fileName,
        fileSize: existingMeta.fileSize > 0 ? existingMeta.fileSize : fileSize,
        totalChunks: existingMeta.totalChunks > 0 ? existingMeta.totalChunks : totalChunks,
        senderId: existingMeta.senderId,
        createdAt: existingMeta.createdAt,
      );
    }

    _fileChunks.putIfAbsent(fileId, () => {});
    _fileChunks[fileId]![chunkIndex] = chunkPath;
    
    // 检查是否收齐全部分片，自动触发合并
    final receivedChunks = _fileChunks[fileId]!.length;
    final meta = _pendingFiles[fileId]!;
    print("📊 已收分片: $receivedChunks / ${meta.totalChunks}");
    
    if (receivedChunks >= meta.totalChunks && !_completedFiles.contains(fileId)) {
      print("🎉 本地扫描分片收齐，开始合并!");
      _mergeChunks(fileId);
    }
  }

  /// 查询并保存分片消息ID（通过会话历史消息）
  Future<List<String>> queryChunkMessageIds(String conversationId, String fileId) async {
    print('🔍 _queryAndSaveChunkMessageIds: conversationId=$conversationId, fileId=$fileId');
    
    if (_chunkMessageIds.containsKey(fileId) && _chunkMessageIds[fileId]!.isNotEmpty) {
      print('📝 已有缓存的消息ID: ${_chunkMessageIds[fileId]}');
      return _chunkMessageIds[fileId]!;
    }
    
    try {
      final isGroup = conversationId.startsWith('group_');
      final res = isGroup 
        ? await TencentImSDKPlugin.v2TIMManager.v2TIMMessageManager.getGroupHistoryMessageList(
            groupID: conversationId,
            count: 100,
          )
        : await TencentImSDKPlugin.v2TIMManager.v2TIMMessageManager.getC2CHistoryMessageList(
            userID: conversationId,
            count: 100,
          );
      
      if (res.code == 0 && res.data != null) {
        final messages = res.data!;
        
        for (final msg in messages) {
          if (msg.elemType != MessageElemType.V2TIM_ELEM_TYPE_FILE) continue;
          
          final fileName = msg.fileElem?.fileName ?? '';
          if (!fileName.startsWith('chunk_')) continue;
          
          final parts = fileName.split('|');
          if (parts.length < 2) continue;
          
          final msgFileId = parts[1];
          if (msgFileId == fileId && msg.id != null) {
            final msgId = msg.id!;
            _chunkMessageIds.putIfAbsent(fileId, () => []);
            if (!_chunkMessageIds[fileId]!.contains(msgId)) {
              _chunkMessageIds[fileId]!.add(msgId);
              print('📝 查询到分片消息ID: $msgId, fileId=$fileId');
            }
          }
        }
      }
      
      return _chunkMessageIds[fileId] ?? [];
    } catch (e) {
      print('❌ 查询分片消息ID失败: $e');
      return [];
    }
  }

  /// 手动触发合并指定 fileId 的分片文件
  Future<void> manualMerge(String fileId, {String? conversationId}) async {
    print('🔧 manualMerge 被调用, fileId=$fileId, conversationId=$conversationId');
    
    // 如果提供了 conversationId，先查询消息ID
    if (conversationId != null) {
      await queryChunkMessageIds(conversationId, fileId);
    }
    
    if (_completedFiles.contains(fileId)) {
      print('⚠️ 文件已处理过');
      if (onError != null) {
        onError!(fileId, '文件已处理过');
      }
      return;
    }

    final metadata = _pendingFiles[fileId];
    if (metadata == null) {
      print('⚠️ 未找到文件元数据');
      if (onError != null) {
        onError!(fileId, '未找到文件元数据');
      }
      return;
    }

    final chunks = _fileChunks[fileId];
    if (chunks == null || chunks.isEmpty) {
      print('⚠️ 未找到分片数据');
      if (onError != null) {
        onError!(fileId, '未找到分片数据');
      }
      return;
    }

    // 检查分片是否完整
    if (chunks.length < metadata.totalChunks) {
      print('⚠️ 分片不完整：${chunks.length}/${metadata.totalChunks}');
      if (onError != null) {
        onError!(fileId, '分片不完整: ${chunks.length}/${metadata.totalChunks}');
      }
      return;
    }

    // 执行合并
    await _mergeChunks(fileId);
  }

  /// 获取所有待合并的文件信息
  List<FileMergeInfo> getPendingMergeInfo() {
    final List<FileMergeInfo> infoList = [];
    for (final entry in _pendingFiles.entries) {
      final fileId = entry.key;
      final metadata = entry.value;
      final chunks = _fileChunks[fileId];
      final receivedCount = chunks?.length ?? 0;
      final isComplete = receivedCount >= metadata.totalChunks && !_completedFiles.contains(fileId);
      
      infoList.add(FileMergeInfo(
        fileId: fileId,
        fileName: metadata.fileName,
        fileSize: metadata.fileSize,
        totalChunks: metadata.totalChunks,
        receivedChunks: receivedCount,
        isComplete: isComplete,
      ));
    }
    return infoList;
  }

  /// 获取所有待删除的分片消息ID
  List<String> getAllChunkMessageIds() {
    final List<String> allMsgIds = [];
    for (final msgIds in _chunkMessageIds.values) {
      for (final msgId in msgIds) {
        if (!allMsgIds.contains(msgId)) {
          allMsgIds.add(msgId);
        }
      }
    }
    return allMsgIds;
  }

  /// 一键删除所有分片文件
  Future<int> deleteAllChunks() async {
    print('🗑️ deleteAllChunks 开始删除...');
    int deletedCount = 0;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dirsToScan = [
        Directory(path.join(appDir.path, tempDirName)),
        Directory(appDir.path),
        await getTemporaryDirectory(),
      ];
      
      for (final dir in dirsToScan) {
        if (!await dir.exists()) continue;
        
        final entities = await dir.list().toList();
        for (final entity in entities) {
          if (entity is File) {
            final fileName = path.basename(entity.path);
            // 删除分片文件和元数据文件
            if (fileName.contains('_chunk_') || 
                fileName.startsWith('chunk_') ||
                fileName.contains('_metadata')) {
              try {
                await entity.delete();
                deletedCount++;
                print('🗑️ 已删除: ${entity.path}');
              } catch (e) {
                print('❌ 删除失败: ${entity.path}, error: $e');
              }
            }
          }
        }
      }
      
      // 清理内存中的数据
      _pendingFiles.clear();
      _fileChunks.clear();
      _completedFiles.clear();
      
      print('🎉 删除完成，共删除 $deletedCount 个文件');
    } catch (e) {
      print('❌ 删除分片文件失败：$e');
    }
    
    return deletedCount;
  }
}
