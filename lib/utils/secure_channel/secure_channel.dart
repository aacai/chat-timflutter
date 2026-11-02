import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 自有端到端加密：X25519 临时密钥协商 + HKDF-SHA256 派生 + ChaCha20-Poly1305 认证加密。
///
/// 纯 Dart，不依赖 IM，可单测。密文带 `§E1§` 前缀，接收端据此区分加密消息和历史明文消息。
///
/// 提供两套信封格式：
/// - [seal]/[unseal]：Base64 字符串，用于文本消息（要塞进 textElem.text）。
/// - [sealToBytes]/[openBytes]：原始字节，用于文件分片（直接落盘/传输，避免 33% 膨胀）。
class SecureChannel {
  static const String marker = "§E1§";
  static final Uint8List markerBytes = Uint8List.fromList(utf8.encode(marker));
  static const int publicKeyBytes = 32;

  static const int _nonceBytes = 12;
  static const int _macBytes = 16;
  static const int _headerBytes = publicKeyBytes + _nonceBytes + _macBytes;

  static final X25519 _keyExchange = X25519();
  static final Chacha20 _cipher = Chacha20.poly1305Aead();
  static final Hkdf _kdf = Hkdf(hmac: Hmac.sha256(), outputLength: publicKeyBytes);

  static Future<List<int>> generatePrivateKey() async =>
      (await _keyExchange.newKeyPair()).extractPrivateKeyBytes();

  static Future<SimpleKeyPair> identityFrom(List<int> privateKey) =>
      _keyExchange.newKeyPairFromSeed(privateKey);

  static Future<List<int>> publicKeyOf(SimpleKeyPair keyPair) async =>
      (await keyPair.extractPublicKey()).bytes;

  static bool looksEncrypted(String text) => text.startsWith(marker);

  static bool looksEncryptedBytes(Uint8List bytes) => _startsWith(bytes, markerBytes);

  static bool _startsWith(Uint8List bytes, Uint8List prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  /// 信封体：临时公钥(32) || nonce(12) || mac(16) || 密文。
  static Future<Uint8List> _sealBody({
    required List<int> peerPublicKey,
    required String context,
    required List<int> plain,
  }) async {
    final ephemeral = await _keyExchange.newKeyPair();
    final key = await _messageKey(
      ownKeyPair: ephemeral,
      peerPublicKey: peerPublicKey,
      context: context,
    );
    final box = await _cipher.encrypt(plain, secretKey: key);
    final header = Uint8List(_headerBytes);
    header.setRange(0, publicKeyBytes, await publicKeyOf(ephemeral));
    header.setRange(publicKeyBytes, publicKeyBytes + _nonceBytes, box.nonce);
    header.setRange(publicKeyBytes + _nonceBytes, _headerBytes, box.mac.bytes);
    final out = Uint8List(_headerBytes + box.cipherText.length)
      ..setRange(0, _headerBytes, header)
      ..setRange(_headerBytes, _headerBytes + box.cipherText.length, box.cipherText);
    return out;
  }

  static Future<List<int>> _openBody(
    Uint8List body,
    SimpleKeyPair ownIdentity,
    String context,
  ) async {
    if (body.length < _headerBytes) {
      throw const FormatException("加密信封不完整");
    }
    final key = await _messageKey(
      ownKeyPair: ownIdentity,
      peerPublicKey: body.sublist(0, publicKeyBytes),
      context: context,
    );
    return _cipher.decrypt(
      SecretBox(
        body.sublist(_headerBytes),
        nonce: body.sublist(publicKeyBytes, publicKeyBytes + _nonceBytes),
        mac: Mac(body.sublist(publicKeyBytes + _nonceBytes, _headerBytes)),
      ),
      secretKey: key,
    );
  }

  /// 文本用：Base64 字符串信封，带 §E1§ 前缀。
  static Future<String> seal({
    required List<int> peerPublicKey,
    required String context,
    required List<int> plain,
  }) async =>
      "$marker${base64Encode(await _sealBody(peerPublicKey: peerPublicKey, context: context, plain: plain))}";

  static Future<List<int>> unseal({
    required SimpleKeyPair ownIdentity,
    required String context,
    required String envelope,
  }) async {
    if (!looksEncrypted(envelope)) {
      throw const FormatException("不是加密信封");
    }
    return _openBody(
      base64Decode(envelope.substring(marker.length)),
      ownIdentity,
      context,
    );
  }

  /// 文件用：原始字节信封，直接落盘/传输，避免 Base64 膨胀。
  static Future<Uint8List> sealToBytes({
    required List<int> peerPublicKey,
    required String context,
    required List<int> plain,
  }) async {
    final body = await _sealBody(peerPublicKey: peerPublicKey, context: context, plain: plain);
    final marked = Uint8List(markerBytes.length + body.length)
      ..setRange(0, markerBytes.length, markerBytes)
      ..setRange(markerBytes.length, markerBytes.length + body.length, body);
    return marked;
  }

  static Future<List<int>> openBytes({
    required Uint8List bytes,
    required SimpleKeyPair ownIdentity,
    required String context,
  }) async {
    if (!looksEncryptedBytes(bytes)) {
      throw const FormatException("不是加密信封");
    }
    return _openBody(bytes.sublist(markerBytes.length), ownIdentity, context);
  }

  /// [context] 是会话 ID / 文件 ID，不同会话即使公钥相同也解不开。
  static Future<SecretKey> _messageKey({
    required KeyPair ownKeyPair,
    required List<int> peerPublicKey,
    required String context,
  }) async {
    final shared = await _keyExchange.sharedSecretKey(
      keyPair: ownKeyPair,
      remotePublicKey: SimplePublicKey(peerPublicKey, type: KeyPairType.x25519),
    );
    return _kdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode("chat-e2ee-v1|$context"),
    );
  }
}
