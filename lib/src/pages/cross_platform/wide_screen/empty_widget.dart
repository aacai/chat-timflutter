import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';

/// 空状态占位。原来的插画 + 浅色渐变在深色界面里非常刺眼，
/// 改成跟随主题的极简样式：一个淡色圆形图标 + 主色标题 + 次级说明。
class EmptyWidget extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;

  const EmptyWidget({
    Key? key,
    required this.title,
    this.description,
    this.icon = Icons.forum_outlined,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = theme.primaryColor ?? const Color(0xFF147AFF);
    return MoveWindow(
      child: Container(
        color: theme.weakBackgroundColor,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(isDark ? 0.14 : 0.10),
              ),
              child: Icon(icon, size: 42, color: primary.withOpacity(0.75)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: theme.darkTextColor,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.weakTextColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
