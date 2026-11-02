// ignore_for_file: unused_field, unused_element, avoid_print, deprecated_member_use

import 'dart:math';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/group_application_list.dart';
import 'package:tencent_cloud_chat_demo/src/group_profile.dart';
import 'package:tencent_cloud_chat_demo/src/provider/custom_sticker_package.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/tencent_page.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_message_element.dart';
import 'package:tencent_cloud_chat_demo/utils/file_transfer/file_transfer_service.dart';
import 'package:tencent_cloud_chat_demo/utils/secure_channel/encryption_service.dart';
import 'package:tencent_cloud_chat_demo/utils/secure_channel/secure_channel.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
  if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart'
  if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/chat_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_text_field_layout/wide.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/widget/tim_uikit_profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

class Chat extends StatefulWidget {
  final V2TimConversation selectedConversation;
  final V2TimMessage? initFindingMsg;
  final VoidCallback? showGroupProfile;
  final ValueChanged<V2TimConversation>? directToChat;

  const Chat({Key? key, required this.selectedConversation, this.initFindingMsg, this.showGroupProfile, this.directToChat}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final TIMUIKitChatController _chatController = TIMUIKitChatController();
  final TextEditingController _inputController = TextEditingController();
  /// 发送端本地明文缓存：key 为 msgID，避免自己发出的加密文本在本地显示成密文。
  final Map<String, String> _myPlaintextCache = {};
  String? backRemark;
  String? conversationName;

  String _getTitle() {
    return backRemark ?? widget.selectedConversation.showName ?? "Chat";
  }

  String? _getConvID() {
    return widget.selectedConversation.type == 1 ? widget.selectedConversation.userID : widget.selectedConversation.groupID;
  }

  /// 选文件并发出去；超过单文件上限自动走分片，界面上仍然只有一条文件气泡。
  Future<void> _pickAndSendFile() async {
    final picked = await FilePicker.platform.pickFiles();
    final sourcePath = picked?.files.isNotEmpty == true ? picked!.files.single.path : null;
    if (sourcePath == null || !mounted) {
      return;
    }
    try {
      await FileTransferService.instance.send(
        controller: _chatController,
        sourcePath: sourcePath,
        conversationID: widget.selectedConversation.conversationID ?? '',
      );
    } catch (e) {
      ToastUtils.toast(TIM_t("文件发送失败") + "$e");
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// 发送端加密文本：用对端公钥封套，密钥由会话 ID 派生；群聊或无公钥降级明文。
  /// 发送后把明文按 msgID 缓存，供本地显示，避免自己看到密文气泡。
  Future<void> _sendEncryptedText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final conv = widget.selectedConversation;
    final peerUserID = EncryptionService.isC2C(conv.conversationID ?? '')
        ? conv.userID
        : null;
    final cipher = await EncryptionService.instance.encryptText(
      peerUserID: peerUserID ?? '',
      conversationID: conv.conversationID ?? '',
      plain: text,
    );
    final msg = V2TimMessage(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      textElem: V2TimTextElem(text: cipher),
    );
    final res = await _chatController.sendMessage(messageInfo: msg);
    final id = res?.data?.msgID;
    if (id != null && id.isNotEmpty) {
      _myPlaintextCache[id] = text;
    }
    _inputController.clear();
  }

  /// 替换默认输入框：纯文本加密输入 + 文件入口（文件走分片端到端加密）。
  /// 注：原生表情/语音/视频面板随默认输入区一并替换，暂未接入。
  Widget _buildEncryptedInput(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    return Container(
      color: theme.weakBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendEncryptedText(_inputController.text),
                decoration: InputDecoration(
                  hintText: TIM_t("输入消息（端到端加密）"),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.weakDividerColor,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.attachment, color: theme.weakTextColor),
              onPressed: _pickAndSendFile,
              tooltip: TIM_t("发送文件"),
            ),
            IconButton(
              icon: Icon(Icons.send, color: theme.primaryColor),
              onPressed: () => _sendEncryptedText(_inputController.text),
              tooltip: TIM_t("发送"),
            ),
          ],
        ),
      ),
    );
  }

  // 收到分片时交给传输服务；补齐后自动合并，合并结果由文件气泡指向。
  void _feedChunkMessage(V2TimMessage message) {
    FileTransferService.instance.onChunkMessage(message).catchError((e) {
      debugPrint('分片处理失败：$e');
    });
  }

  /// 入站文本消息解密：仅 C2C 且带加密前缀才尝试；失败/无前缀原样返回，保证不丢消息。
  Future<V2TimMessage> _decryptIncoming(V2TimMessage message) async {
    final text = message.textElem?.text;
    final convID = widget.selectedConversation.conversationID ?? '';
    if (text == null ||
        !SecureChannel.looksEncrypted(text) ||
        !EncryptionService.isC2C(convID)) {
      return message;
    }
    // 发送端自己刚发出的加密文本：用本地明文缓存显示，避免看到密文气泡。
    final id = message.msgID;
    if (id != null && _myPlaintextCache.containsKey(id)) {
      message.textElem?.text = _myPlaintextCache[id];
      return message;
    }
    final plain = await EncryptionService.instance
        .decryptText(conversationID: convID, envelope: text);
    if (plain != text) {
      message.textElem?.text = plain;
    }
    return message;
  }

  _onTapAvatar(String userID, TapDownDetails tapDetails, TUITheme theme) {
    final isWideScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    if (isWideScreen) {
      onClickUserName(Offset(min(tapDetails.globalPosition.dx, MediaQuery.of(context).size.width - 350), min(tapDetails.globalPosition.dy, MediaQuery.of(context).size.height - 490)), theme, userID);
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfile(
              userID: userID,
              onRemarkUpdate: (String newRemark) {
                setState(() {
                  conversationName = newRemark;
                });
              },
            ),
          ));
    }
  }

  _itemClick(String id, BuildContext context, V2TimConversation conversation, VoidCallback closeFunc) async {
    closeFunc();
    switch (id) {
      case "sendMsg":
        if (widget.directToChat != null) {
          widget.directToChat!(conversation);
        }
        break;
    }
  }

  _buildBottomOperationList(BuildContext context, V2TimConversation conversation, VoidCallback closeFunc, TUITheme theme) {
    List operationList = [
      {
        "label": TIM_t("发送消息"),
        "id": "sendMsg",
      }
    ];

    return operationList.map((e) {
      return TIMUIKitProfileWidget.wideButton(
        margin: const EdgeInsets.symmetric(vertical: 0),
        smallCardMode: true,
        onPressed: () => _itemClick(e["id"] ?? "", context, conversation, closeFunc),
        text: e["label"] ?? "",
        color: theme.primaryColor ?? hexToColor("3e4b67"),
      );
    }).toList();
  }

  void onClickUserName(Offset offset, TUITheme theme, [String? user]) {
    final conversationType = widget.selectedConversation.type;
    if (conversationType == 1 || user != null) {
      final userID = user ?? widget.selectedConversation.userID;
      TUIKitWidePopup.showPopupWindow(
          operationKey: TUIKitWideModalOperationKey.showUserProfileFromChat,
          context: context,
          isDarkBackground: false,
          width: 350,
          offset: offset,
          height: (widget.selectedConversation.type == 2) ? 490 : 444,
          child: (closeFunc) => Container(
                padding: const EdgeInsets.only(top: 20, left: 10, right: 10),
                child: TIMUIKitProfile(
                  smallCardMode: true,
                  profileWidgetBuilder: ProfileWidgetBuilder(customBuilderOne: (bool isFriend, V2TimFriendInfo friendInfo, V2TimConversation conversation) {
                    // If you don't allow sending message when friendship not exist,
                    // please not comment the following lines.

                    // if(!isFriend){
                    //   return Container();
                    // }
                    return Column(children: _buildBottomOperationList(context, conversation, closeFunc, theme));
                  }),
                  profileWidgetsOrder: [
                    ProfileWidgetEnum.userInfoCard,
                    ProfileWidgetEnum.operationDivider,
                    ProfileWidgetEnum.remarkBar,
                    ProfileWidgetEnum.genderBar,
                    ProfileWidgetEnum.birthdayBar,
                    ProfileWidgetEnum.operationDivider,
                    ProfileWidgetEnum.addToBlockListBar,
                    ProfileWidgetEnum.pinConversationBar,
                    ProfileWidgetEnum.messageMute,
                    ProfileWidgetEnum.addAndDeleteArea,
                    if (widget.selectedConversation.type == 2) ProfileWidgetEnum.customBuilderOne,
                  ],
                  userID: userID ?? "",
                ),
              ));
    } else {
      if (widget.showGroupProfile != null) {
        widget.showGroupProfile!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final LocalSetting localSetting = Provider.of<LocalSetting>(context);
    final isWideScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final groupID = widget.selectedConversation.groupID;
    final groupType = widget.selectedConversation.groupType;
    List<String> notAllowGroupType = [GroupType.Community, GroupType.AVChatRoom];
    bool canAddVotePlugin = false;
    if (TencentUtils.checkString(groupID) != null && TencentUtils.checkString(groupType) != null && !notAllowGroupType.contains(groupType)) {
      canAddVotePlugin = true;
    }
    return TencentPage(
      name: 'chat',
      child: Stack(
        children: [
          TIMUIKitChat(
        // New field, instead of `conversationID` / `conversationType` / `groupAtInfoList` / `conversationShowName` in previous.
        conversation: widget.selectedConversation,
        conversationShowName: conversationName ?? _getTitle(),
        controller: _chatController,
        // 自定义输入区：文本走端到端加密，文件入口保留（分片端到端加密）。
        textFieldBuilder: _buildEncryptedInput,
        lifeCycle: ChatLifeCycle(newMessageWillMount: (V2TimMessage message) async {
          _feedChunkMessage(message);
          return await _decryptIncoming(message);
        }, didGetHistoricalMessageList: (List<V2TimMessage> messageList) async {
          // 上次没合并完的传输，进会话时补齐分片继续合并。
          for (final message in messageList) {
            _feedChunkMessage(message);
          }
          // 历史消息入站解密（异步钩子，可解密）。
          return await Future.wait(messageList.map(_decryptIncoming));
        }, messageShouldMount: (V2TimMessage message) {
          return !FileTransferService.shouldHide(message.cloudCustomData);
        }, messageListShouldMount: (messageList) {
          // 同步钩子，无法等待解密；解密已在 didGetHistoricalMessageList / newMessageWillMount 完成。
          List<V2TimMessage> list = [];
          for (V2TimMessage message in messageList) {
            CallingMessageDataProvider provide = CallingMessageDataProvider(message);
            if (provide.isCallingSignal && provide.excludeFromHistory) {
              continue;
            }
            FileTransferService.instance.decorate(message);
            list.add(message);
          }
          return list;
        }),
        onDealWithGroupApplication: (String groupId) {
          if (!isWideScreen) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupApplicationList(
                  groupID: groupId,
                ),
              ),
            );
          } else {
            TUIKitWidePopup.showPopupWindow(
              operationKey: TUIKitWideModalOperationKey.addGroup,
              context: context,
              width: MediaQuery.of(context).size.width * 0.55,
              height: MediaQuery.of(context).size.width * 0.45,
              title: TIM_t("进群申请列表"),
              child: (closeFuncSendApplication) => TIMUIKitGroupApplicationList(groupID: groupID ?? ""),
            );
          }
        },
        groupAtInfoList: widget.selectedConversation.groupAtInfoList,
        showTotalUnReadCount: true,
        config: TIMUIKitChatConfig(
            stickerPanelConfig: StickerPanelConfig(
              useQQStickerPackage: true,
              unicodeEmojiList: TUIKitStickerConstData.defaultUnicodeEmojiList,
              useTencentCloudChatStickerPackage: true,
              customStickerPackages: Provider.of<CustomStickerPackageData>(context).customStickerPackageList,
            ),
            onTapLink: PlatformUtils().isWeb
                ? (link) {
                    LinkUtils.launchURL(context, "https://comm.qq.com/link_page/index.html?target=$link");
                  }
                : null,
            showC2cMessageEditStatus: true,
            isAllowClickAvatar: true,
            isMemberCanAtAll: true,
            isAtWhenReply: false,
            isAtWhenReplyDynamic: (V2TimMessage message) {
              return false;
            },
            isAllowLongPressMessage: true,
            isShowReadingStatus: localSetting.isShowReadingStatus,
            isShowGroupReadingStatus: true,
            notificationTitle: "",
            isSupportMarkdownForTextMessage: false,
            urlPreviewType: UrlPreviewType.previewCardAndHyperlink,
            isUseMessageReaction: true,
            groupReadReceiptPermissionList: [GroupReceiptAllowType.work, GroupReceiptAllowType.meeting, GroupReceiptAllowType.public],
            faceURIPrefix: (String path) {
              if (path.contains("assets/custom_face_resource/")) {
                return "";
              }
              int? dirNumber;
              if (path.contains("yz")) {
                dirNumber = 4350;
              }
              if (path.contains("ys")) {
                dirNumber = 4351;
              }
              if (path.contains("gcs")) {
                dirNumber = 4352;
              }
              if (dirNumber != null) {
                return "assets/custom_face_resource/$dirNumber/";
              } else {
                return "";
              }
            },
            faceURISuffix: (String path) {
              if (!path.contains("@2x.png")) {
                return "@2x.png";
              }
              return "";
            },
            // 桌面端控件条自带的文件按钮不支持大文件，换成走同一个传输服务的入口。
            desktopControlBarConfig: DesktopControlBarConfig(showSendFileButton: false),
            additionalDesktopControlBarItems: [
              DesktopControlBarItem(
                item: "file",
                icon: Icons.insert_drive_file_outlined,
                showName: TIM_t("文件"),
                onClick: (offset) => _pickAndSendFile(),
              ),
            ]),
        conversationID: _getConvID() ?? '',
        conversationType: ConvType.values[widget.selectedConversation.type ?? 1],
        onTapAvatar: (userID, tapDetails) => _onTapAvatar(userID, tapDetails, theme),
        initFindingMsg: widget.initFindingMsg,
        messageItemBuilder: MessageItemBuilder(
          messageRowBuilder: (message, messageWidget, onScrollToIndex, isNeedShowJumpStatus, clearJumpStatus, onScrollToIndexBegin) {
            if (MessageUtils.isGroupCallingMessage(message)) {
              // If group call message, not use default layout.
              return messageWidget;
            }
            if (MessageUtils.getCustomGroupCreatedOrDismissedString(message).isNotEmpty) {
              return messageWidget;
            }
            return null;
          },
          customMessageItemBuilder: (message, isShowJump, clearJump) {
            return CustomMessageElem(
              message: message,
              isShowJump: isShowJump,
              clearJump: clearJump,
              chatController: _chatController,
            );
          },
          renderingDirectionCallback: (message) {
            final isCallOutgoing = CustomMessageElem.isC2CCallOutgoing(message);
            if (isCallOutgoing != null) {
              V2TimUserFullInfo? userFullInfo;
              if (isCallOutgoing) {
                userFullInfo = TIMUIKitCore.getInstance().loginUserInfo;
              } else {
                userFullInfo = V2TimUserFullInfo(
                    userID: widget.selectedConversation.userID,
                    faceUrl: widget.selectedConversation.faceUrl,
                    nickName: widget.selectedConversation.showName);
              }

              return RenderingDirectionResult(
                isSelf: isCallOutgoing,
                userInfo: userFullInfo,
              );
            } else {
              return null;
            }
          },
        ),
        // 自定义输入区已接管发送入口，默认 more 面板（文件/语音/视频）不再渲染，
        // 文件入口已在 _buildEncryptedInput 中保留；语音/视频的通话面板为已知待补项。
        appBarConfig: AppBar(
          actions: [
            IconButton(
                padding: const EdgeInsets.only(left: 8, right: 16),
                onPressed: () async {
                  final conversationType = widget.selectedConversation.type;

                  if (conversationType == 1) {
                    final userID = widget.selectedConversation.userID;
                    // if had remark modified its will back new remark
                    String? newRemark = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfile(
                            userID: userID!,
                            onRemarkUpdate: (String newRemark) {
                              setState(() {
                                conversationName = newRemark;
                              });
                            },
                          ),
                        ));
                    setState(() {
                      backRemark = newRemark;
                    });
                  } else {
                    final groupID = widget.selectedConversation.groupID;
                    if (groupID != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupProfilePage(
                              groupID: groupID,
                            ),
                          ));
                    }
                  }
                },
                icon: Icon(
                  Icons.more_horiz,
                  color: hexToColor("010000"),
                  size: 20,
                ))
          ],
        ),
        customAppBar: isWideScreen
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 60),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: TIMUIKitAppBar(
                            onClickTitle: (details) {
                              onClickUserName(Offset(details.globalPosition.dx, details.globalPosition.dy), theme);
                            },
                            config: AppBar(
                              backgroundColor: isWideScreen ? hexToColor("fafafa") : hexToColor("f2f3f5"),
                              actions: [
                                IconButton(
                                    padding: const EdgeInsets.only(left: 8, right: 16),
                                    onPressed: () async {
                                      onClickUserName(Offset(MediaQuery.of(context).size.width - 380, 30), theme);
                                    },
                                    icon: Icon(
                                      Icons.more_horiz,
                                      color: hexToColor("010000"),
                                      size: 20,
                                    ))
                              ],
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      conversationName ?? _getTitle(),
                                      style: TextStyle(
                                        color: hexToColor("010000"),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : null,
          ),
        ],
      ),
    );
  }
}
