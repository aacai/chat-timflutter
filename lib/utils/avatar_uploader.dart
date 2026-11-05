import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class AvatarUploadResult {
  final String? url;
  final String? errorCode;

  const AvatarUploadResult.success(this.url) : errorCode = null;
  const AvatarUploadResult.failure(this.errorCode) : url = null;

  bool get isSuccess => url != null && url!.isNotEmpty;
}

/// 自定义头像上传。
///
/// 项目没有独立的图片上传后端，这里复用 IM SDK 的图片消息上传通道：
/// 创建图片消息 -> 发给自己（排除会话最后一条消息与未读数）-> 取回云端
/// 图片 URL -> 写入 selfInfo.faceUrl -> 删除这条仅用于上传的消息。
/// URL 由 IM 侧托管，其它端也能正常显示。
class AvatarUploader {
  static const int maxBytes = 5 * 1024 * 1024;

  static Future<AvatarUploadResult> upload(String imagePath) async {
    if (kIsWeb) {
      return const AvatarUploadResult.failure("WEB_URL_ONLY");
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      return const AvatarUploadResult.failure("FILE_MISSING");
    }
    if (await file.length() > maxBytes) {
      return const AvatarUploadResult.failure("FILE_TOO_LARGE");
    }

    final selfID = TIMUIKitCore.getInstance().loginUserInfo?.userID ?? "";
    if (selfID.isEmpty) {
      return const AvatarUploadResult.failure("NOT_LOGIN");
    }

    final manager = TencentImSDKPlugin.v2TIMManager.getMessageManager();
    final created = await manager.createImageMessage(imagePath: imagePath);
    final message = created.data?.messageInfo;
    if (created.code != 0 || message == null) {
      return const AvatarUploadResult.failure("UPLOAD_FAILED");
    }

    final sent = await manager.sendMessage(
      message: message,
      receiver: selfID,
      groupID: "",
      isExcludedFromLastMessage: true,
      isExcludedFromUnreadCount: true,
    );
    if (sent.code != 0 || sent.data == null) {
      return const AvatarUploadResult.failure("UPLOAD_FAILED");
    }

    String? url;
    for (final image in sent.data!.imageElem?.imageList ?? []) {
      final candidate = image?.url;
      if (candidate != null && candidate.startsWith("http")) {
        url = candidate;
        break;
      }
    }

    final msgID = sent.data!.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      await manager.deleteMessages(msgIDs: [msgID]);
    }

    if (url == null || url.isEmpty) {
      return const AvatarUploadResult.failure("NO_URL");
    }
    return AvatarUploadResult.success(url);
  }
}
