import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/secure_channel/secure_channel.dart';

void main() {
  late List<int> aliceSeed;
  late List<int> bobSeed;
  late List<int> mallorySeed;
  late List<int> alicePub;
  late List<int> bobPub;

  setUp(() async {
    aliceSeed = await SecureChannel.generatePrivateKey();
    bobSeed = await SecureChannel.generatePrivateKey();
    mallorySeed = await SecureChannel.generatePrivateKey();
    alicePub = await SecureChannel.publicKeyOf(await SecureChannel.identityFrom(aliceSeed));
    bobPub = await SecureChannel.publicKeyOf(await SecureChannel.identityFrom(bobSeed));
  });

  group("SecureChannel.seal/unseal", () {
    test("收发双方用同一会话 ID 能还原原文", () async {
      const context = "c2c_alice_bob";
      final plain = utf8.encode("明天下午三点开会");

      final envelope = await SecureChannel.seal(
        peerPublicKey: bobPub,
        context: context,
        plain: plain,
      );
      final opened = await SecureChannel.unseal(
        ownIdentity: await SecureChannel.identityFrom(bobSeed),
        context: context,
        envelope: envelope,
      );

      expect(opened, plain);
    });

    test("二进制原文原样还原", () async {
      final plain = Uint8List.fromList(List<int>.generate(1024, (i) => i % 256));
      final envelope = await SecureChannel.seal(
        peerPublicKey: bobPub,
        context: "conv",
        plain: plain,
      );
      final opened = await SecureChannel.unseal(
        ownIdentity: await SecureChannel.identityFrom(bobSeed),
        context: "conv",
        envelope: envelope,
      );

      expect(opened, plain);
    });

    test("空原文也能走一遍信封", () async {
      final envelope = await SecureChannel.seal(
        peerPublicKey: bobPub,
        context: "conv",
        plain: const [],
      );

      expect(SecureChannel.looksEncrypted(envelope), isTrue);
      expect(
        await SecureChannel.unseal(
          ownIdentity: await SecureChannel.identityFrom(bobSeed),
          context: "conv",
          envelope: envelope,
        ),
        isEmpty,
      );
    });

    test("同一份原文两次加密结果不同", () async {
      final first = await SecureChannel.seal(
        peerPublicKey: bobPub,
        context: "conv",
        plain: utf8.encode("hello"),
      );
      final second = await SecureChannel.seal(
        peerPublicKey: bobPub,
        context: "conv",
        plain: utf8.encode("hello"),
      );

      expect(first == second, isFalse);
    });

    test("会话 ID 不匹配时解不开", () async {
      final envelope = await SecureChannel.seal(
        peerPublicKey: bobPub,
        context: "conv_a",
        plain: utf8.encode("secret"),
      );

      await expectLater(
        SecureChannel.unseal(
          ownIdentity: await SecureChannel.identityFrom(bobSeed),
          context: "conv_b",
          envelope: envelope,
        ),
        throwsA(anything),
      );
    });

    test("第三方拿不到明文", () async {
      final envelope = await SecureChannel.seal(
        peerPublicKey: bobPub,
        context: "conv",
        plain: utf8.encode("secret"),
      );

      await expectLater(
        SecureChannel.unseal(
          ownIdentity: await SecureChannel.identityFrom(mallorySeed),
          context: "conv",
          envelope: envelope,
        ),
        throwsA(anything),
      );
    });

    test("密文被篡改时认证失败", () async {
      final envelope = await SecureChannel.seal(
        peerPublicKey: bobPub,
        context: "conv",
        plain: utf8.encode("secret"),
      );
      final bytes = base64Decode(envelope.substring(SecureChannel.marker.length));
      bytes[bytes.length - 1] ^= 0x01;
      final tampered =
          "${SecureChannel.marker}${base64Encode(bytes)}";

      await expectLater(
        SecureChannel.unseal(
          ownIdentity: await SecureChannel.identityFrom(bobSeed),
          context: "conv",
          envelope: tampered,
        ),
        throwsA(anything),
      );
    });
  });

  group("SecureChannel 信封格式", () {
    test("明文消息不会被误判成加密消息", () {
      expect(SecureChannel.looksEncrypted("明天下午三点开会"), isFalse);
      expect(SecureChannel.looksEncrypted(""), isFalse);
      expect(SecureChannel.looksEncrypted(base64Encode(utf8.encode("hello"))), isFalse);
    });

    test("没有标记直接报错，不返回半截明文", () async {
      await expectLater(
        SecureChannel.unseal(
          ownIdentity: await SecureChannel.identityFrom(bobSeed),
          context: "conv",
          envelope: "明文消息",
        ),
        throwsFormatException,
      );
    });

    test("截断的信封报错", () async {
      await expectLater(
        SecureChannel.unseal(
          ownIdentity: await SecureChannel.identityFrom(bobSeed),
          context: "conv",
          envelope: "${SecureChannel.marker}AAAA",
        ),
        throwsFormatException,
      );
    });

    test("身份密钥重建后公钥不变", () async {
      final again = await SecureChannel.publicKeyOf(await SecureChannel.identityFrom(aliceSeed));

      expect(again, alicePub);
    });

    test("每把身份密钥的私钥都是 32 字节", () async {
      expect(aliceSeed.length, 32);
      expect(alicePub.length, SecureChannel.publicKeyBytes);
    });
  });
}
