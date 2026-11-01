import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 自有端到端加密：X25519 临时密钥协商 + HKDF-SHA256 派生 + ChaCha20-Poly1305 认证加密。
///
/// 纯 Dart，不依赖 IM，可单测。密文带 `§E1§` 前缀，接收端据此区分加密消息和历史明文消息。
class SecureChannel {
  static const String marker = "§E1§";
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

  /// 信封：临时公钥(32) || nonce(12) || mac(16) || 密文，整体 Base64。
  static Future<String> seal({
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
    return "$marker${base64Encode(out)}";
  }

  static Future<List<int>> unseal({
    required SimpleKeyPair ownIdentity,
    required String context,
    required String envelope,
  }) async {
    if (!looksEncrypted(envelope)) {
      throw const FormatException("不是加密信封");
    }
    final bytes = base64Decode(envelope.substring(marker.length));
    if (bytes.length < _headerBytes) {
      throw const FormatException("加密信封不完整");
    }
    final key = await _messageKey(
      ownKeyPair: ownIdentity,
      peerPublicKey: bytes.sublist(0, publicKeyBytes),
      context: context,
    );
    return _cipher.decrypt(
      SecretBox(
        bytes.sublist(_headerBytes),
        nonce: bytes.sublist(publicKeyBytes, publicKeyBytes + _nonceBytes),
        mac: Mac(bytes.sublist(publicKeyBytes + _nonceBytes, _headerBytes)),
      ),
      secretKey: key,
    );
  }

  /// [context] 是会话 ID，不同会话即使公钥相同也解不开。
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
