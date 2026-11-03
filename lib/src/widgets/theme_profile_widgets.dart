import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

/// 主题感知的资料操作行，替代 TUIKit 内置的白色 OperationItem。
class ThemeOperationItem extends StatelessWidget {
  final String operationName;
  final String? operationDescription;
  final bool isEmpty;
  final Widget? operationRightWidget;

  /// arrow / switch
  final String type;
  final bool? operationValue;
  final void Function(bool newValue)? onSwitchChange;
  final bool smallCardMode;
  final bool showArrow;
  final VoidCallback? onTap;

  const ThemeOperationItem({
    Key? key,
    required this.operationName,
    this.isEmpty = false,
    this.operationDescription,
    this.operationRightWidget,
    this.type = "arrow",
    this.operationValue,
    this.onSwitchChange,
    this.smallCardMode = false,
    this.showArrow = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDesktop =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    return GestureDetector(
      onTap: onTap,
      child: Container(
      color: theme.weakBackgroundColor,
      padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: smallCardMode ? 8 : (isDesktop ? 10 : 12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  operationName,
                  style: TextStyle(fontSize: 15, color: theme.darkTextColor),
                ),
                if (operationDescription != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      operationDescription!,
                      style: TextStyle(fontSize: 12, color: theme.weakTextColor),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (type == "switch")
            Transform.scale(
              scale: 0.8,
              child: CupertinoSwitch(
                value: operationValue ?? false,
                onChanged: onSwitchChange,
                activeColor: theme.primaryColor,
              ),
            )
          else ...[
            Flexible(
                child: operationRightWidget ?? const SizedBox.shrink()),
            if (showArrow)
              Icon(Icons.keyboard_arrow_right,
                  size: 20, color: theme.weakTextColor),
          ],
        ],
      ),
    ),
    );
  }
}

/// 主题感知的个人资料头部卡片，替代 TIMUIKitProfileUserInfoCard。
class ThemeUserInfoCard extends StatelessWidget {
  final V2TimUserFullInfo? userInfo;
  final VoidCallback? onClickAvatar;
  final bool showArrowRightIcon;

  const ThemeUserInfoCard({
    Key? key,
    this.userInfo,
    this.onClickAvatar,
    this.showArrowRightIcon = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final nickName = userInfo?.nickName ?? "";
    final userID = userInfo?.userID ?? "";
    final signature = userInfo?.selfSignature ?? "";
    final showName = nickName.isNotEmpty ? nickName : userID;
    return Container(
      color: theme.weakBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClickAvatar,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Avatar(
                faceUrl: userInfo?.faceUrl ?? "",
                showName: showName,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.darkTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  "ID: $userID",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.weakTextColor),
                ),
                if (signature.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    signature,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.weakTextColor),
                  ),
                ],
              ],
            ),
          ),
          if (showArrowRightIcon)
            Icon(Icons.keyboard_arrow_right, color: theme.weakTextColor),
        ],
      ),
    );
  }
}

/// 主题感知的分割线。
class ThemeProfileDivider extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry margin;

  const ThemeProfileDivider({
    Key? key,
    this.height = 1,
    this.margin = const EdgeInsets.symmetric(vertical: 16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Container(
      height: height,
      margin: margin,
      color: theme.weakDividerColor,
    );
  }
}

/// 主题感知的通用列表项（头像 + 标题 + 副标题 + 右侧箭头/自定义），
/// 替代 TUIKit 列表项在深色下白底的问题。
class ThemeListItem extends StatelessWidget {
  final String showName;
  final String? faceUrl;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double avatarSize;

  const ThemeListItem({
    Key? key,
    required this.showName,
    this.faceUrl,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.avatarSize = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: theme.weakBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: Avatar(faceUrl: faceUrl ?? "", showName: showName),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.darkTextColor, fontSize: 16),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: theme.weakTextColor, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null)
              Icon(Icons.keyboard_arrow_right, color: theme.weakTextColor),
          ],
        ),
      ),
    );
  }
}
