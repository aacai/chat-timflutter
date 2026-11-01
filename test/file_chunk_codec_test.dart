import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/file_transfer/chunk_codec.dart';

Uint8List _pattern(int length, int seed) {
  final rand = Random(seed);
  return Uint8List.fromList(List<int>.generate(length, (_) => rand.nextInt(256)));
}

List<ChunkHeader> _headers(String fileId, String name, int totalSize, List<ChunkArtifact> parts) {
  return parts
      .map((part) => ChunkHeader(
            fileId: fileId,
            fileName: name,
            fileSize: totalSize,
            totalChunks: parts.length,
            index: part.index,
            chunkSize: part.size,
            chunkMd5: part.md5,
          ))
      .toList();
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp("chunk_codec_test");
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group("ChunkHeader", () {
    test("encode/decode 往返一致", () {
      const header = ChunkHeader(
        fileId: "f1",
        fileName: "报告.zip",
        fileSize: 1234567,
        totalChunks: 14,
        index: 13,
        chunkSize: 90 * 1024 * 1024,
        chunkMd5: "abc",
      );

      final decoded = ChunkHeader.decode(header.encode());

      expect(decoded, isNotNull);
      expect(decoded!.fileId, "f1");
      expect(decoded.fileName, "报告.zip");
      expect(decoded.totalChunks, 14);
      expect(decoded.index, 13);
      expect(decoded.chunkMd5, "abc");
    });

    test("非分片消息的 cloudCustomData 一律解不出来", () {
      expect(ChunkHeader.decode(null), isNull);
      expect(ChunkHeader.decode(""), isNull);
      expect(ChunkHeader.decode("not json"), isNull);
      expect(ChunkHeader.decode('{"messageFeature":{"needTyping":1,"version":1}}'), isNull);
      expect(ChunkHeader.decode('{"v":99,"fid":"x"}'), isNull);
      expect(ChunkHeader.decode('{"v":$chunkProtocolVersion}'), isNull);
    });
  });

  group("ChunkCodec", () {
    test("按边界切分，末片为余数", () async {
      final bytes = _pattern(1000, 7);
      final source = File('${dir.path}/source.bin')..writeAsBytesSync(bytes);

      final parts = await ChunkCodec.split(
        sourcePath: source.path,
        directory: dir.path,
        fileId: "fid",
        chunkBytes: 300,
      );

      expect(parts.map((e) => e.size), [300, 300, 300, 100]);
      expect(parts.map((e) => e.index), [0, 1, 2, 3]);
      expect(parts.every((part) => File(part.path).lengthSync() == part.size), isTrue);
    });

    test("整除时不产生 0 字节末片", () async {
      final source = File('${dir.path}/exact.bin')..writeAsBytesSync(_pattern(600, 8));

      final parts = await ChunkCodec.split(
        sourcePath: source.path,
        directory: dir.path,
        fileId: "fid",
        chunkBytes: 300,
      );

      expect(parts.length, 2);
      expect(parts.last.size, 300);
    });

    test("切分再合并能还原原文件", () async {
      final bytes = _pattern(10 * 1024 * 1024 + 513, 9);
      final source = File('${dir.path}/big.bin')..writeAsBytesSync(bytes);

      final parts = await ChunkCodec.split(
        sourcePath: source.path,
        directory: dir.path,
        fileId: "fid",
        chunkBytes: 2 * 1024 * 1024,
      );
      final merged = await ChunkCodec.merge(
        expected: _headers("fid", "big.bin", bytes.length, parts),
        chunkPathByIndex: {for (final part in parts) part.index: part.path},
        destinationPath: '${dir.path}/restored.bin',
      );

      expect(File(merged).readAsBytesSync(), bytes);
      expect(await ChunkCodec.md5OfFile(merged), await ChunkCodec.md5OfFile(source.path));
    });

    test("缺片时合并不落地半个文件", () async {
      final bytes = _pattern(900, 10);
      final source = File('${dir.path}/missing.bin')..writeAsBytesSync(bytes);
      final parts = await ChunkCodec.split(
        sourcePath: source.path,
        directory: dir.path,
        fileId: "fid",
        chunkBytes: 300,
      );
      final destination = '${dir.path}/should_not_exist.bin';

      await expectLater(
        ChunkCodec.merge(
          expected: _headers("fid", "missing.bin", bytes.length, parts),
          chunkPathByIndex: {for (final part in parts.take(2)) part.index: part.path},
          destinationPath: destination,
        ),
        throwsStateError,
      );
      expect(File(destination).existsSync(), isFalse);
    });

    test("分片被篡改时 MD5 校验拦下来", () async {
      final bytes = _pattern(600, 11);
      final source = File('${dir.path}/tampered.bin')..writeAsBytesSync(bytes);
      final parts = await ChunkCodec.split(
        sourcePath: source.path,
        directory: dir.path,
        fileId: "fid",
        chunkBytes: 300,
      );
      File(parts.first.path).writeAsBytesSync(Uint8List(300));

      await expectLater(
        ChunkCodec.merge(
          expected: _headers("fid", "tampered.bin", bytes.length, parts),
          chunkPathByIndex: {for (final part in parts) part.index: part.path},
          destinationPath: '${dir.path}/out.bin',
        ),
        throwsFormatException,
      );
    });

    test("分片大小与元数据不符时拒绝合并", () async {
      final bytes = _pattern(600, 12);
      final source = File('${dir.path}/short.bin')..writeAsBytesSync(bytes);
      final parts = await ChunkCodec.split(
        sourcePath: source.path,
        directory: dir.path,
        fileId: "fid",
        chunkBytes: 300,
      );
      final headers = _headers("fid", "short.bin", bytes.length, parts)
          .map((h) => ChunkHeader(
                fileId: h.fileId,
                fileName: h.fileName,
                fileSize: h.fileSize,
                totalChunks: h.totalChunks,
                index: h.index,
                chunkSize: h.chunkSize + 1,
                chunkMd5: "",
              ))
          .toList();

      await expectLater(
        ChunkCodec.merge(
          expected: headers,
          chunkPathByIndex: {for (final part in parts) part.index: part.path},
          destinationPath: '${dir.path}/out.bin',
        ),
        throwsFormatException,
      );
    });

    test("newFileId 每次不同", () {
      expect(ChunkCodec.newFileId("a.bin", 1) == ChunkCodec.newFileId("a.bin", 1), isFalse);
    });

    test("deleteChunks 忽略不存在的文件", () async {
      final source = File('${dir.path}/del.bin')..writeAsBytesSync(utf8.encode("x"));
      final parts = await ChunkCodec.split(
        sourcePath: source.path,
        directory: dir.path,
        fileId: "fid",
        chunkBytes: 1,
      );

      await ChunkCodec.deleteChunks([...parts.map((e) => e.path), '${dir.path}/ghost.chunk']);

      expect(parts.every((part) => !File(part.path).existsSync()), isTrue);
    });
  });
}
