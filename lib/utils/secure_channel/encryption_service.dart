import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

import 'secure_channel.dart';

/// 私钥落盘的偏好键。
const String _privKeyPref = 'e2ee_private_key';

/// 个人签名里嵌入公钥的前缀，便于对端识别与解析。
const String _pubKeyMarker = '§K1§';

/// 端到端加密总线：管理身份密钥、与对端交换公钥、提供文本/文件的加解密。
///
/// 公钥通过用户「个人签名」(selfSignature) 字段发布，对端用 [getUsersInfo] 取出即可，
/// 无需额外信令通道。C2C 会话按 conversationID 派生会话密钥；群聊无统一密钥，退化为明文。
class EncryptionService {
  EncryptionService._();

  static final EncryptionService instance = EncryptionService._();

  SimpleKeyPair? _identity;
  final Map<String, List<int>> _peerCache = {};

  Future<SimpleKeyPair> get identity async {
    if (_identity == null) {
      await _ensureLoaded();
    }
    return _identity!;
  }

  Future<void> _ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_privKeyPref);
    if (raw != null && raw.isNotEmpty) {
      _identity = await SecureChannel.identityFrom(base64Decode(raw));
    } else {
      final priv = await SecureChannel.generatePrivateKey();
      _identity = await SecureChannel.identityFrom(priv);
      await prefs.setString(_privKeyPref, base64Encode(priv));
    }
  }

  Future<List<int>> get publicKey async => SecureChannel.publicKeyOf(await identity);

  /// 登录后调用：确保身份密钥就绪，并把公钥发布到个人签名。
  Future<void> init() async {
    await _ensureLoaded();
    await publishPublicKey();
  }

  /// 把公钥写入个人签名（仅更新该字段，不影响其它资料）。
  Future<void> publishPublicKey() async {
    final pk = base64Encode(await publicKey);
    try {
      await TencentImSDKPlugin.v2TIMManager.setSelfInfo(
        userFullInfo: V2TimUserFullInfo(selfSignature: '$_pubKeyMarker$pk'),
      );
    } catch (e) {
      debugPrint("发布 E2EE 公钥失败：$e");
    }
  }

  /// 取对端公钥（带缓存）；拿不到（未发布/非好友等）返回 null，调用方应退化为明文。
  Future<List<int>?> peerPublicKey(String userID) async {
    if (_peerCache.containsKey(userID)) {
      return _peerCache[userID];
    }
    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getUsersInfo(userIDList: [userID]);
      final list = res.data;
      if (list != null && list.isNotEmpty) {
        final key = _parse(list.first.selfSignature ?? '');
        if (key != null) {
          _peerCache[userID] = key;
          return key;
        }
      }
    } catch (e) {
      debugPrint("获取对端公钥失败：$e");
    }
    return null;
  }

  List<int>? _parse(String signature) {
    if (!signature.startsWith(_pubKeyMarker)) {
      return null;
    }
    try {
      return base64Decode(signature.substring(_pubKeyMarker.length));
    } catch (_) {
      return null;
    }
  }

  /// 登出/切换账号时清掉对端缓存，避免串号。
  void clearPeerCache() => _peerCache.clear();

  /// 是否支持端到端加密：仅 C2C。群聊返回 false。
  static bool isC2C(String conversationID) =>
      conversationID.isEmpty || !conversationID.startsWith('group_');

  /// 加密文本。无对端公钥时返回原文（明文降级），保证消息不丢。
  Future<String> encryptText({
    required String peerUserID,
    required String conversationID,
    required String plain,
  }) async {
    final pk = await peerPublicKey(peerUserID);
    if (pk == null) return plain;
    return SecureChannel.seal(
      peerPublicKey: pk,
      context: conversationID,
      plain: utf8.encode(plain),
    );
  }

  /// 解密文本。格式不符或密钥不对都返回原文，保证不丢消息。
  Future<String> decryptText({
    required String conversationID,
    required String envelope,
  }) async {
    if (!SecureChannel.looksEncrypted(envelope)) return envelope;
    try {
      return utf8.decode(await SecureChannel.unseal(
        ownIdentity: await identity,
        context: conversationID,
        envelope: envelope,
      ));
    } catch (_) {
      return envelope;
    }
  }

  /// 加密文件字节（大文件分片用）。无对端公钥时返回原文（明文降级）。
  Future<Uint8List> encryptFile({
    required String peerUserID,
    required String context,
    required Uint8List data,
  }) async {
    final pk = await peerPublicKey(peerUserID);
    if (pk == null) return data;
    return SecureChannel.sealToBytes(
      peerPublicKey: pk,
      context: context,
      plain: data,
    );
  }

  /// 解密文件字节。格式不符或失败返回原文。
  Future<Uint8List> decryptFile({
    required String context,
    required Uint8List data,
  }) async {
    if (!SecureChannel.looksEncryptedBytes(data)) return data;
    try {
      return Uint8List.fromList(await SecureChannel.openBytes(
        bytes: data,
        ownIdentity: await identity,
        context: context,
      ));
    } catch (_) {
      return data;
    }
  }
}
