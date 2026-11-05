import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/utils/avatar_saver.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// 点击头像后展开的大图预览：圆形大图 + 捏合缩放 + 保存到本地 / 更换头像。
Future<void> showAvatarViewer({
  required BuildContext context,
  required String imageUrl,
  required String showName,
  VoidCallback? onChangeAvatar,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: TIM_t("关闭"),
    barrierColor: Colors.black.withValues(alpha: 0.82),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _AvatarViewer(
      imageUrl: imageUrl,
      showName: showName,
      onChangeAvatar: onChangeAvatar,
    ),
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) =>
        FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );
}

class _AvatarViewer extends StatefulWidget {
  final String imageUrl;
  final String showName;
  final VoidCallback? onChangeAvatar;

  const _AvatarViewer({
    Key? key,
    required this.imageUrl,
    required this.showName,
    this.onChangeAvatar,
  }) : super(key: key);

  @override
  State<_AvatarViewer> createState() => _AvatarViewerState();
}

class _AvatarViewerState extends State<_AvatarViewer> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    if (widget.imageUrl.isEmpty) {
      ToastUtils.toast(TIM_t("当前为默认头像，暂无可保存的图片"));
      return;
    }
    setState(() => _saving = true);
    final result = await AvatarSaver.save(widget.imageUrl);
    if (!mounted) return;
    setState(() => _saving = false);
    ToastUtils.toast(
        result.success ? TIM_t("已保存到本地") : TIM_t("保存失败，请重试"));
  }

  Widget _image(double diameter) {
    if (widget.imageUrl.isEmpty) {
      return CircleAvatar(
        radius: diameter / 2,
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        child: Text(
          widget.showName.isNotEmpty ? widget.showName[0].toUpperCase() : "?",
          style: const TextStyle(fontSize: 64, color: Colors.white),
        ),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Image.network(
          widget.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
            radius: diameter / 2,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            child: const Icon(Icons.person, size: 72, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap,
      {bool busy = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(icon, size: 22, color: Colors.white),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final diameter = min(size.width * 0.7, 280.0);
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Center(
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: InteractiveViewer(
                clipBehavior: Clip.none,
                minScale: 1,
                maxScale: 4,
                child: _image(diameter),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 16,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: TIM_t("关闭"),
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _action(Icons.download_rounded, TIM_t("保存到本地"), _save,
                      busy: _saving),
                  if (widget.onChangeAvatar != null) ...[
                    const SizedBox(width: 12),
                    _action(Icons.edit_rounded, TIM_t("更换头像"), () {
                      Navigator.of(context).pop();
                      Future.microtask(() => widget.onChangeAvatar?.call());
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
