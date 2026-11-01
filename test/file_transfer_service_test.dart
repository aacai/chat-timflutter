import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/file_transfer/chunk_codec.dart';
import 'package:tencent_cloud_chat_demo/utils/file_transfer/file_transfer_service.dart';

ChunkHeader _header({int index = 0, int totalChunks = 4}) => ChunkHeader(
      fileId: "f1",
      fileName: "movie.mp4",
      fileSize: 300 * 1024 * 1024,
      totalChunks: totalChunks,
      index: index,
      chunkSize: 90 * 1024 * 1024,
      chunkMd5: "abc",
    );

void main() {
  group("分片消息对 UI 不可见", () {
    test("只有第 0 片参与渲染", () {
      expect(FileTransferService.shouldHide(_header(index: 0).encode()), isFalse);
      expect(FileTransferService.shouldHide(_header(index: 1).encode()), isTrue);
      expect(FileTransferService.shouldHide(_header(index: 3).encode()), isTrue);
    });

    test("不是我们的分片消息一律照常渲染", () {
      for (final data in [null, "", "{}", "not json", '{"v":2,"fid":"x","idx":1}']) {
        expect(FileTransferService.shouldHide(data), isFalse, reason: "cloudCustomData=$data");
      }
    });

    test("其它业务占用 cloudCustomData 也不会被误判", () {
      expect(FileTransferService.shouldHide('{"fid":"chat_custom","idx":1}'), isFalse);
    });
  });

  group("传输索引", () {
    test("记录能原样序列化回来", () {
      const record = TransferRecord(
        fileId: "f1",
        fileName: "movie.mp4",
        fileSize: 300,
        totalChunks: 4,
        localPath: "/tmp/movie.mp4",
      );

      expect(TransferRecord.fromJson(record.toJson()), isNotNull);
      final restored = TransferRecord.fromJson(record.toJson())!;
      expect(restored.fileId, record.fileId);
      expect(restored.fileName, record.fileName);
      expect(restored.fileSize, record.fileSize);
      expect(restored.totalChunks, record.totalChunks);
      expect(restored.localPath, record.localPath);
    });

    test("缺字段的脏数据直接丢弃", () {
      expect(TransferRecord.fromJson({"fid": "f1"}), isNull);
      expect(TransferRecord.fromJson({"path": "/tmp/a"}), isNull);
      expect(TransferRecord.fromJson("f1"), isNull);
    });
  });
}
