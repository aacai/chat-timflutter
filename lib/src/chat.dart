// ignore_for_file: unused_field, unused_element, avoid_print, deprecated_member_use

import 'dart:math';

import 'package:bitsdojo_window/bitsdojo_window.dart';
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
import 'package:tencent_cloud_chat_demo/utils/file_send_helper.dart';
import 'package:tencent_cloud_chat_demo/utils/file_chunk_assembler.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
  if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/chat_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
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
  String? backRemark;
  final V2TIMManager sdkInstance = TIMUIKitCore.getSDKInstance();
  String? conversationName;
  
  // 文件上传进度
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  String _getTitle() {
    return backRemark ?? widget.selectedConversation.showName ?? "Chat";
  }

  String? _getConvID() {
    return widget.selectedConversation.type == 1 ? widget.selectedConversation.userID : widget.selectedConversation.groupID;
  }

  ConvType _getConvType() {
    return widget.selectedConversation.type == 1 ? ConvType.c2c : ConvType.group;
  }

  // 发送文件（支持大文件）
  Future<void> _sendFile(TUIChatSeparateViewModel model) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      await FileSendHelper.sendFile(
        model: model,
        convID: _getConvID() ?? '',
        convType: _getConvType(),
        onProgress: (fileId, progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
        onComplete: (fileId) {
          setState(() {
            _isUploading = false;
            _uploadProgress = 1.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件发送成功')),
          );
        },
        onError: (error) {
          setState(() {
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发送失败：$error')),
          );
        },
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('错误：$e')),
      );
    }
  }

  // 处理接收到的消息（用于分片文件合并）
  FileChunkAssembler? _fileChunkAssembler;

  Future<void> _handleReceivedMessage(V2TimMessage message) async {
    debugPrint('🔔 _handleReceivedMessage 被调用, msgID=${message.id}, elemType=${message.elemType}');
    
    // 检查是否是文件消息
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_FILE) {
      debugPrint('不是文件消息，跳过处理');
      return;
    }
    
    final fileName = message.fileElem?.fileName ?? '';
    debugPrint('收到文件消息: $fileName');
    
    if (!fileName.startsWith('chunk_')) {
      debugPrint('普通文件，不是分片，跳过');
      return;
    }
    
    debugPrint('检测到分片文件，准备处理');
    
    _fileChunkAssembler ??= FileChunkAssembler(
      onProgress: (fileId, progress) {
        debugPrint('文件接收进度：${(progress * 100).toStringAsFixed(1)}%');
      },
      onComplete: (fileId, filePath, fileName, msgIdsToDelete) async {
        debugPrint('文件接收完成：$fileName, 保存位置: $filePath');
        debugPrint('需要删除的分片消息ID: $msgIdsToDelete');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('大文件接收完成：$fileName\n保存位置: $filePath')),
          );
          ToastUtils.toast('大文件接收完成：$fileName');
        }
      },
      onError: (fileId, error) {
        debugPrint('文件接收错误：$error');
        ToastUtils.toast('文件接收错误：$error');
      },
    );

    await _fileChunkAssembler!.onMessageReceived(message);
  }

  void _showMergeDialog() async {
    // 先初始化并扫描本地分片
    _fileChunkAssembler ??= FileChunkAssembler(
      onProgress: (fileId, progress) {
        debugPrint('文件接收进度：${(progress * 100).toStringAsFixed(1)}%');
      },
      onComplete: (fileId, filePath, fileName, msgIdsToDelete) async {
        debugPrint('文件接收完成：$fileName, 保存位置: $filePath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('大文件接收完成：$fileName\n保存位置: $filePath')),
          );
          ToastUtils.toast('大文件接收完成：$fileName');
        }
      },
      onError: (fileId, error) {
        debugPrint('文件接收错误：$error');
        ToastUtils.toast('文件接收错误：$error');
      },
    );
    
    // 扫描本地分片文件
    await _fileChunkAssembler!.scanLocalChunks();
    
    final pendingList = _fileChunkAssembler!.getPendingMergeInfo();
    
    if (pendingList.isEmpty) {
      ToastUtils.toast('暂无待合并的分片文件');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('分片文件合并'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pendingList.length,
            itemBuilder: (context, index) {
              final info = pendingList[index];
              final canMerge = info.isComplete;
              return ListTile(
                title: Text(info.fileName),
                subtitle: Text('${info.receivedChunks}/${info.totalChunks} 分片'),
                trailing: canMerge 
                  ? ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _doMerge(info.fileId);
                      },
                      child: const Text('合并'),
                    )
                  : Text(
                      '等待中',
                      style: TextStyle(color: Colors.grey),
                    ),
                enabled: canMerge,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final count = await _fileChunkAssembler!.deleteAllChunks();
              if (mounted) {
                Navigator.pop(context);
                ToastUtils.toast('已删除 $count 个分片文件');
              }
            },
            child: const Text('删除全部', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _doMerge(String fileId) async {
    if (_fileChunkAssembler == null) {
      ToastUtils.toast('合并器未初始化');
      return;
    }

    try {
      await _fileChunkAssembler!.manualMerge(fileId);
      ToastUtils.toast('合并完成');
    } catch (e) {
      ToastUtils.toast('合并失败: $e');
    }
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ToastUtils.toast('聊天页面已加载 - 文件分片功能已启用');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(Chat oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isWideScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
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
        lifeCycle: ChatLifeCycle(newMessageWillMount: (V2TimMessage message) async {
          await _handleReceivedMessage(message);
          return message;
        }, messageShouldMount: (V2TimMessage message) {
          return true;
        }, messageListShouldMount: (messageList) {
          List<V2TimMessage> list = [];
          for (V2TimMessage message in messageList) {
            CallingMessageDataProvider provide = CallingMessageDataProvider(message);
            if (!provide.isCallingSignal || !provide.excludeFromHistory) {
              list.add(message);
            }
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
            additionalDesktopControlBarItems: [
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
        morePanelConfig: MorePanelConfig(
          showVideoCall: true,
          showVoiceCall: true,
          extraAction: [
            MorePanelItem(
              id: 'large_file',
              icon: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/ic_file.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              title: TIM_t("大文件"),
              onTap: (context) async {
                final model = Provider.of<TUIChatSeparateViewModel>(context, listen: false);
                await _sendFile(model);
              },
            ),
          ],
        ),
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
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Row(
                        children: [
                          if (_isUploading)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.primaryColor?.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: _uploadProgress,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : null,
          ),
          // 全局悬浮球 - 发送文件
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isUploading)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor?.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                FloatingActionButton(
                  heroTag: 'file_send_btn',
                  onPressed: () {
                    _showMergeDialog();
                  },
                  backgroundColor: theme.primaryColor ?? Colors.blue,
                  child: const Icon(Icons.merge_type, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
