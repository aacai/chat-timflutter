import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

/// 传给子窗口 engine 的启动参数。
///
/// 两个 Flutter engine 不共享 Dart 堆，会话对象只能以 JSON 快照传递。
class ChatWindowArgs {
  final V2TimConversation conversation;

  const ChatWindowArgs(this.conversation);

  // SDK 的 toJson 是原生 snake_case，且 conv_id 存的是 userID/groupID；
  // 这里直接传 View 需要的字段快照，避免子窗口再依赖 SDK 的反序列化。
  String encode() => jsonEncode({
        'conversation': {
          'conversationID': conversation.conversationID,
          'userID': conversation.userID,
          'groupID': conversation.groupID,
          'showName': conversation.showName,
          'faceUrl': conversation.faceUrl,
          'type': conversation.type,
        },
      });
}

/// 子窗口只认这份会话快照，不需要 IM SDK 模型。
class ChatWindowConversation {
  final String conversationID;
  final String? userID;
  final String? groupID;
  final String? showName;
  final String? faceUrl;
  final int? type;

  const ChatWindowConversation({
    required this.conversationID,
    this.userID,
    this.groupID,
    this.showName,
    this.faceUrl,
    this.type,
  });

  factory ChatWindowConversation.fromJson(Map raw) {
    final json = Map<String, dynamic>.from(raw);
    return ChatWindowConversation(
      conversationID: json['conversationID'] as String? ?? '',
      userID: json['userID'] as String?,
      groupID: json['groupID'] as String?,
      showName: json['showName'] as String?,
      faceUrl: json['faceUrl'] as String?,
      type: json['type'] as int?,
    );
  }

  static ChatWindowConversation? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return ChatWindowConversation.fromJson(
        Map<String, dynamic>.from(decoded['conversation'] as Map),
      );
    } catch (_) {
      return null;
    }
  }
}

/// 跨窗口传输用的轻量消息 DTO。
///
/// 子窗口是纯 View，不 import IM SDK、不持有任何 SDK 实例；主窗口把
/// V2TimMessage 转成这份 DTO，顺带完成端到端解密。
class ChatWindowMessage {
  final String msgID;
  final bool isSelf;
  final String sender;
  final String nickName;
  final String faceUrl;
  final int timestamp;

  /// text / image / file / other / revoked
  final String kind;
  final String text;
  final String imageUrl;
  final String fileName;
  final int fileSize;

  const ChatWindowMessage({
    required this.msgID,
    required this.isSelf,
    required this.sender,
    required this.nickName,
    required this.faceUrl,
    required this.timestamp,
    required this.kind,
    required this.text,
    required this.imageUrl,
    required this.fileName,
    required this.fileSize,
  });

  factory ChatWindowMessage.fromJson(Map raw) {
    final json = Map<String, dynamic>.from(raw);
    return ChatWindowMessage(
      msgID: json['msgID'] as String? ?? '',
      isSelf: json['isSelf'] as bool? ?? false,
      sender: json['sender'] as String? ?? '',
      nickName: json['nickName'] as String? ?? '',
      faceUrl: json['faceUrl'] as String? ?? '',
      timestamp: json['timestamp'] as int? ?? 0,
      kind: json['kind'] as String? ?? 'other',
      text: json['text'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'msgID': msgID,
        'isSelf': isSelf,
        'sender': sender,
        'nickName': nickName,
        'faceUrl': faceUrl,
        'timestamp': timestamp,
        'kind': kind,
        'text': text,
        'imageUrl': imageUrl,
        'fileName': fileName,
        'fileSize': fileSize,
      };

  ChatWindowMessage asRevoked() => ChatWindowMessage(
        msgID: msgID,
        isSelf: isSelf,
        sender: sender,
        nickName: nickName,
        faceUrl: faceUrl,
        timestamp: timestamp,
        kind: 'revoked',
        text: '',
        imageUrl: '',
        fileName: '',
        fileSize: 0,
      );
}

/// 主窗口侧的独立聊天窗口注册表。
///
/// 主窗口是唯一的 IM SDK owner：子窗口的所有读写都通过跨窗口 MethodChannel
/// 发请求，主窗口的 SDK listener 再把事件推回对应子窗口。
class ChatWindowManager {
  ChatWindowManager._();

  static final ChatWindowManager instance = ChatWindowManager._();

  /// conversationID -> windowId
  final Map<String, int> _windowIds = {};

  /// windowId -> conversationID
  final Map<int, String> _conversationIds = {};

  static bool get isSupported => PlatformUtils().isDesktop;

  Future<void> open(V2TimConversation conversation) async {
    final conversationID = conversation.conversationID;
    if (!isSupported || conversationID.isEmpty) return;
    await _pruneClosedWindows();
    final existing = _windowIds[conversationID];
    if (existing != null) {
      await DesktopMultiWindow.invokeMethod(existing, 'chat.focus');
      return;
    }
    final window = await DesktopMultiWindow.createWindow(
      ChatWindowArgs(conversation).encode(),
    );
    _windowIds[conversationID] = window.windowId;
    _conversationIds[window.windowId] = conversationID;
    await window.setFrame(const Rect.fromLTWH(0, 0, 880, 680));
    await window.center();
    await window.setTitle(conversation.showName ?? conversationID);
    await window.show();
  }

  Future<void> broadcast(
      String conversationID, String method, dynamic arguments) async {
    final windowId = _windowIds[conversationID];
    if (windowId == null) return;
    try {
      await DesktopMultiWindow.invokeMethod(windowId, method, arguments);
    } catch (_) {}
  }

  Future<void> broadcastAll(String method, dynamic arguments) async {
    if (!isSupported) return;
    for (final windowId in await DesktopMultiWindow.getAllSubWindowIds()) {
      try {
        await DesktopMultiWindow.invokeMethod(windowId, method, arguments);
      } catch (_) {}
    }
  }

  void forgetWindow(int windowId) {
    final conversationID = _conversationIds.remove(windowId);
    if (conversationID != null) {
      _windowIds.remove(conversationID);
    }
  }

  /// 登出/被踢下线后子窗口必须一起关闭。
  Future<void> closeAll() async {
    await broadcastAll('chat.logout', null);
    _windowIds.clear();
    _conversationIds.clear();
  }

  /// 用户直接点原生关闭按钮时子窗口来不及上报，下次打开时按存活列表清理。
  Future<void> _pruneClosedWindows() async {
    final alive = (await DesktopMultiWindow.getAllSubWindowIds()).toSet();
    _windowIds.removeWhere((_, id) => !alive.contains(id));
    _conversationIds.removeWhere((id, _) => !alive.contains(id));
  }
}
