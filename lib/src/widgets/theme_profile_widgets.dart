import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

/// 资料页的操作行：独立圆角卡片，替代 TUIKit 内置的白色 OperationItem。
/// 卡片化之后不再需要额外的分割线来分组，靠卡片间距做视觉分层。
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: theme.weakBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: smallCardMode ? 10 : (isDesktop ? 12 : 14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    operationName,
                    style:
                        TextStyle(fontSize: 15, color: theme.darkTextColor),
                  ),
                  if (operationDescription != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        operationDescription!,
                        style: TextStyle(
                            fontSize: 12, color: theme.weakTextColor),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (type == "switch")
              Transform.scale(
                scale: 0.85,
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
                Icon(Icons.chevron_right,
                    size: 20, color: theme.weakTextColor),
            ],
          ],
        ),
      ),
    );
  }
}

/// 资料页顶部的个人资料头：大头像 + 昵称 + ID + 个性签名，
/// 用主色淡渐变做背景，和下面的信息卡片形成层次。
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
    final primary = theme.primaryColor ?? CommonColor.primaryColor;
    final nickName = userInfo?.nickName ?? "";
    final userID = userInfo?.userID ?? "";
    final signature = userInfo?.selfSignature ?? "";
    final showName = nickName.isNotEmpty ? nickName : userID;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            Color.lerp(primary, Colors.black, 0.28) ?? primary,
          ],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClickAvatar,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.onPrimary.withOpacity(0.5), width: 2),
              ),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Avatar(
                  faceUrl: userInfo?.faceUrl ?? "",
                  showName: showName,
                ),
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
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  "ID: $userID",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.onPrimaryWeak),
                ),
                if (signature.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    signature,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.onPrimaryWeak),
                  ),
                ],
              ],
            ),
          ),
          if (showArrowRightIcon)
            const Icon(Icons.chevron_right, color: AppColors.onPrimaryWeak),
        ],
      ),
    );
  }
}

/// 资料页分隔线。操作项已经卡片化，这里只保留一个零高度的占位，
/// 避免再画一条线把卡片切碎。
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
    return const SizedBox.shrink();
  }
}

/// 通用列表项（头像 + 标题 + 副标题 + 右侧箭头/自定义），
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
              Icon(Icons.chevron_right, color: theme.weakTextColor),
          ],
        ),
      ),
    );
  }
}
