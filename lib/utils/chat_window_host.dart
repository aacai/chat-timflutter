// ignore_for_file: avoid_print, deprecated_member_use

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:tencent_cloud_chat_demo/utils/secure_channel/encryption_service.dart';
import 'package:tencent_cloud_chat_demo/utils/secure_channel/secure_channel.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

import 'chat_window.dart';

/// 主窗口侧的「聊天服务」：整个进程里只有它持有 IM SDK。
///
/// 子窗口是纯 View，通过跨窗口 MethodChannel 发请求；本类负责历史消息、
/// 发送、端到端加解密、已读，并把 SDK listener 的事件推回对应子窗口。
/// 不注册新的 SDK 初始化/登录，也不占用第二个原生回调端口，
/// 因此不会影响主窗口收消息。
class ChatWindowHost {
  ChatWindowHost._();

  static final ChatWindowHost instance = ChatWindowHost._();

  final Map<String, String> _plaintextCache = {};
  bool _started = false;

  V2TIMManager get _sdk => TIMUIKitCore.getSDKInstance();

  /// 在 IM SDK init 成功后调用一次；幂等。
  Future<void> start() async {
    if (_started || !ChatWindowManager.isSupported) return;
    _started = true;
    DesktopMultiWindow.setMethodHandler((call, _) => handle(call.method, call.arguments));
    // SDK 的高级消息 listener 是 list 语义，这里追加一个不会覆盖 uikit 的监听器。
    // 注册失败不能拖垮主窗口启动：历史/发送仍可用，只是少了实时推送。
    try {
      await _sdk.getMessageManager().addAdvancedMsgListener(
            listener: V2TimAdvancedMsgListener(
              onRecvNewMessage: _onNewMessage,
              onRecvMessageRevoked: _onRevoked,
            ),
          );
    } catch (error) {
      print('独立窗口消息监听注册失败：$error');
    }
  }

  Future<dynamic> handle(String method, dynamic raw) async {
    final args = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    switch (method) {
      case 'chat.whoAmI':
        return _whoAmI();
      case 'chat.getMessages':
        return _getMessages(args);
      case 'chat.sendText':
        return _sendText(args);
      case 'chat.markRead':
        return _markRead(args);
      case 'chat.openInMain':
        return _openInMain();
      case 'chat.closed':
        final windowId = args['windowId'];
        if (windowId is int) ChatWindowManager.instance.forgetWindow(windowId);
        return true;
    }
    return null;
  }

  Future<Map<String, dynamic>> _whoAmI() async {
    final res = await _sdk.getLoginUser();
    return {'ok': true, 'userID': res.data ?? ''};
  }

  Future<Map<String, dynamic>> _getMessages(Map<String, dynamic> args) async {
    final conversationID = args['conversationID'] as String? ?? '';
    final count = args['count'] as int? ?? 30;
    final lastMsgID = args['lastMsgID'] as String?;
    final target = _splitConversationID(conversationID);
    if (target == null) return {'ok': false, 'messages': <dynamic>[]};

    final res = await _sdk.getMessageManager().getHistoryMessageList(
          count: count,
          userID: target.$1,
          groupID: target.$2,
          lastMsgID: lastMsgID,
          getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
        );
    if (res.code != 0) {
      return {'ok': false, 'messages': <dynamic>[], 'error': res.desc};
    }
    final list = res.data ?? <V2TimMessage>[];
    final dtos = await Future.wait(
      list.map((message) => _toDto(message, conversationID)),
    );
    dtos.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return {
      'ok': true,
      'messages': dtos.map((e) => e.toJson()).toList(),
      'hasMore': list.length >= count,
    };
  }

  Future<Map<String, dynamic>> _sendText(Map<String, dynamic> args) async {
    final conversationID = args['conversationID'] as String? ?? '';
    final text = (args['text'] as String? ?? '').trim();
    final target = _splitConversationID(conversationID);
    if (text.isEmpty || target == null) return {'ok': false};
    final userID = target.$1;
    final groupID = target.$2 ?? '';

    final cipher = await EncryptionService.instance.encryptText(
      peerUserID: groupID.isEmpty ? (userID ?? '') : '',
      conversationID: conversationID,
      plain: text,
    );
    final createRes = await _sdk.getMessageManager().createTextMessage(text: cipher);
    final message = createRes.data?.messageInfo;
    if (message == null) return {'ok': false};

    // macOS 上 SDK 返回的 messageInfo 只有壳，本地气泡和发送都要写回消息体。
    message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
    message.textElem = V2TimTextElem(text: cipher);
    final login = await _sdk.getLoginUser();
    if (login.data != null) message.sender = login.data;
    message.isSelf = true;

    final sendRes = await _sdk.getMessageManager().sendMessage(
          message: message,
          receiver: userID ?? '',
          groupID: groupID,
        );
    if (sendRes.code != 0) {
      return {'ok': false, 'error': sendRes.desc};
    }

    final sentID = sendRes.data?.msgID;
    final localID = createRes.data?.id ?? message.id;
    if (sentID != null && sentID.isNotEmpty) _plaintextCache[sentID] = text;
    if (localID != null && localID.isNotEmpty) _plaintextCache[localID] = text;

    final dto = ChatWindowMessage(
      msgID: sentID ?? localID ?? '',
      isSelf: true,
      sender: message.sender ?? '',
      nickName: message.nickName ?? '',
      faceUrl: '',
      timestamp: message.timestamp ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      kind: 'text',
      text: text,
      imageUrl: '',
      fileName: '',
      fileSize: 0,
    );
    await ChatWindowManager.instance.broadcast(
        conversationID, 'chat.newMessage', dto.toJson());
    return {'ok': true, 'message': dto.toJson()};
  }

  Future<Map<String, dynamic>> _markRead(Map<String, dynamic> args) async {
    final conversationID = args['conversationID'] as String? ?? '';
    if (conversationID.startsWith('c2c_')) {
      await _sdk
          .getMessageManager()
          .markC2CMessageAsRead(userID: conversationID.substring(4));
    }
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _openInMain() async {
    await WindowController.main().show();
    return {'ok': true};
  }

  void _onNewMessage(V2TimMessage message) {
    final conversationID = _messageConversationID(message);
    if (conversationID.isEmpty) return;
    () async {
      final dto = await _toDto(message, conversationID);
      await ChatWindowManager.instance.broadcast(
          conversationID, 'chat.newMessage', dto.toJson());
    }();
  }

  void _onRevoked(String msgID) {
    ChatWindowManager.instance.broadcastAll('chat.revoked', {'msgID': msgID});
  }

  Future<ChatWindowMessage> _toDto(
      V2TimMessage message, String conversationID) async {
    var kind = 'other';
    var text = '';
    var imageUrl = '';
    var fileName = '';
    var fileSize = 0;

    final rawText = message.textElem?.text;
    if (rawText != null) {
      kind = 'text';
      text = await _plainText(message, rawText, conversationID);
    } else if (message.imageElem != null) {
      kind = 'image';
      final images = message.imageElem!.imageList;
      if (images != null && images.isNotEmpty) {
        imageUrl = images
                .lastWhere(
                  (image) => image?.url?.isNotEmpty == true,
                  orElse: () => null,
                )
                ?.url ??
            '';
      }
    } else if (message.fileElem != null) {
      kind = 'file';
      fileName = message.fileElem!.fileName ?? '';
      fileSize = message.fileElem!.fileSize ?? 0;
    }

    return ChatWindowMessage(
      msgID: message.msgID ?? message.id ?? '',
      isSelf: message.isSelf ?? false,
      sender: message.sender ?? '',
      nickName: message.nickName ?? '',
      faceUrl: message.faceUrl ?? '',
      timestamp: message.timestamp ?? 0,
      kind: kind,
      text: text,
      imageUrl: imageUrl,
      fileName: fileName,
      fileSize: fileSize,
    );
  }

  Future<String> _plainText(
      V2TimMessage message, String raw, String conversationID) async {
    if (!SecureChannel.looksEncrypted(raw) ||
        !EncryptionService.isC2C(conversationID)) {
      return raw;
    }
    final msgID = message.msgID;
    if (msgID != null && _plaintextCache.containsKey(msgID)) {
      return _plaintextCache[msgID]!;
    }
    return EncryptionService.instance
        .decryptText(conversationID: conversationID, envelope: raw);
  }

  /// c2c_xxx -> (xxx, null)；group_xxx -> (null, xxx)
  (String?, String?)? _splitConversationID(String conversationID) {
    if (conversationID.startsWith('group_') && conversationID.length > 6) {
      return (null, conversationID.substring(6));
    }
    if (conversationID.startsWith('c2c_') && conversationID.length > 4) {
      return (conversationID.substring(4), null);
    }
    return null;
  }

  String _messageConversationID(V2TimMessage message) {
    // Web 兼容模型没有这个 getter；桌面原生模型才有，故走动态读取。
    final raw = (message as dynamic).messageConvID;
    if (raw is String && raw.isNotEmpty) return raw;
    final groupID = message.groupID;
    if (groupID != null && groupID.isNotEmpty) return 'group_$groupID';
    final userID = message.userID;
    if (userID != null && userID.isNotEmpty) return 'c2c_$userID';
    return '';
  }
}
