import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'file_chunk_uploader.dart';

/// 文件发送助手 - 支持大文件分片上传
class FileSendHelper {
  // 文件大小限制（100MB）
  static const int FILE_MAX_SIZE = 100 * 1024 * 1024;

  /// 发送文件（自动判断是否需要分片）
  /// 这个方法完全绕过 UIKit 的限制检查
  static Future<void> sendFile({
    required dynamic model, // TUIChatSeparateViewModel 或 MessageService
    required String convID,
    required ConvType convType,
    Function(String fileId, double progress)? onProgress,
    Function(String fileId)? onComplete,
    Function(String error)? onError,
  }) async {
    try {
      // 直接使用 FilePicker 选择文件，绕过 UIKit 的限制
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) {
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        throw Exception('无法获取文件路径');
      }

      final file = File(filePath);
      final fileSize = await file.length();

      print('选择文件：${filePath.split('/').last}, 大小：${fileSize / 1024 / 1024} MB');

      // 判断是否需要分片
      if (fileSize > FILE_MAX_SIZE) {
        print('文件大于 100MB，使用分片上传');
        // 大文件，使用分片上传
        await _sendFileInChunks(
          model: model,
          filePath: filePath,
          convID: convID,
          convType: convType,
          onProgress: onProgress,
          onComplete: onComplete,
          onError: onError,
        );
      } else {
        print('文件小于 100MB，直接发送');
        // 小文件，直接发送
        await _sendNormalFile(
          model: model,
          filePath: filePath,
          convID: convID,
          convType: convType,
        );
        
        if (onComplete != null) {
          onComplete('normal_file');
        }
      }
    } catch (e) {
      print('发送文件失败：$e');
      if (onError != null) {
        onError(e.toString());
      }
    }
  }

  /// 发送普通文件（小于 100MB）
  static Future<void> _sendNormalFile({
    required TUIChatSeparateViewModel model,
    required String filePath,
    required String convID,
    required ConvType convType,
  }) async {
    final fileSize = await File(filePath).length();

    await model.sendFileMessage(
      filePath: filePath,
      size: fileSize,
      convID: convID,
      convType: convType,
    );
  }

  /// 分片上传大文件
  static Future<void> _sendFileInChunks({
    required TUIChatSeparateViewModel model,
    required String filePath,
    required String convID,
    required ConvType convType,
    Function(String fileId, double progress)? onProgress,
    Function(String fileId)? onComplete,
    Function(String error)? onError,
  }) async {
    try {
      final uploader = FileChunkUploader();
      
      // 1. 生成文件唯一 ID
      final fileId = await uploader.generateFileId(filePath);
      
      // 2. 分割文件
      final chunkPaths = await uploader.splitFile(filePath);
      final totalChunks = chunkPaths.length;
      
      // 3. 获取文件信息
      final file = File(filePath);
      final fileSize = await file.length();
      final fileName = filePath.split('/').last;

      // 4. 发送文件元数据消息（使用自定义消息）
      await _sendFileMetadata(
        model: model,
        fileId: fileId,
        fileName: fileName,
        fileSize: fileSize,
        totalChunks: totalChunks,
        convID: convID,
        convType: convType,
      );

      // 5. 依次发送每个分片
      int uploadedChunks = 0;
      for (int i = 0; i < chunkPaths.length; i++) {
        final chunkPath = chunkPaths[i];
        
        // 获取分片信息
        final chunkInfo = await uploader.getChunkInfo(
          fileId: fileId,
          filePath: filePath,
          chunkIndex: i,
          totalChunks: totalChunks,
        );

        // 构造分片文件名（包含元数据）
        // 格式：chunk_index|fileId|originalFileName|totalChunks|fileSize|chunkIndex|chunkSize|chunkMd5
        final chunkFileName = 'chunk_$i|$fileId|$fileName|$totalChunks|$fileSize|${chunkInfo.chunkIndex}|${chunkInfo.chunkSize}|${chunkInfo.chunkMd5}';

        // 发送分片文件消息
        await model.sendFileMessage(
          filePath: chunkPath,
          fileName: chunkFileName,
          size: chunkInfo.chunkSize,
          convID: convID,
          convType: convType,
        );

        uploadedChunks++;
        
        // 通知进度
        if (onProgress != null) {
          final progress = uploadedChunks / totalChunks;
          onProgress(fileId, progress);
        }

        // 添加延迟，避免发送过快触发频率限制
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 6. 清理临时分片文件
      await uploader.cleanupTempFiles(fileId);

      // 7. 通知完成
      if (onComplete != null) {
        onComplete(fileId);
      }

      print('大文件分片上传完成：$fileName, 共 $totalChunks 个分片');
    } catch (e) {
      print('分片上传失败：$e');
      if (onError != null) {
        onError(e.toString());
      }
      rethrow;
    }
  }

  /// 发送文件元数据（使用自定义消息）
  static Future<void> _sendFileMetadata({
    required TUIChatSeparateViewModel model,
    required String fileId,
    required String fileName,
    required int fileSize,
    required int totalChunks,
    required String convID,
    required ConvType convType,
  }) async {
    // 第一个分片发送时已经包含了元数据，不需要单独发送
    // 元数据通过分片文件名的格式传递
    print('文件元数据: fileId=$fileId, fileName=$fileName, fileSize=$fileSize, totalChunks=$totalChunks');
  }
}
