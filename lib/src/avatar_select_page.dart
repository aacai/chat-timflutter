import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/app_navigation.dart';
import 'package:tencent_cloud_chat_demo/utils/avatar_uploader.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class AvatarSelectPage extends StatefulWidget {
  static const String avatarFaceUrl =
      "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_%s.png";
  static const int avatarFaceCount = 26;

  final List<String> avatarURLList = [];
  final TIMUIKitProfileController? controller;
  final String selectedAvatarUrl;

  AvatarSelectPage(
      {Key? key, required this.controller, required this.selectedAvatarUrl})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => AvatarSelectPageState();
}

class AvatarSelectPageState extends State<AvatarSelectPage> {
  bool _uploading = false;
  late String _selectedUrl;

  @override
  void initState() {
    super.initState();
    _selectedUrl = widget.selectedAvatarUrl;
    for (int i = 0; i < AvatarSelectPage.avatarFaceCount; i++) {
      widget.avatarURLList.add(AvatarSelectPage.avatarFaceUrl
          .replaceAll("%s", (i + 1).toString()));
    }
  }

  String _errorText(String? code) {
    switch (code) {
      case "FILE_TOO_LARGE":
        return TIM_t("图片不能超过 5MB，请换一张较小的图片");
      case "WEB_URL_ONLY":
        return TIM_t("浏览器端请使用图片链接");
      case "NOT_LOGIN":
        return TIM_t("登录状态已失效，请重新登录");
      default:
        return TIM_t("上传失败，请改用图片链接");
    }
  }

  Future<void> _applyAvatar(String url) async {
    final result = await widget.controller?.updateAvatar(url);
    if (!mounted) return;
    if (result?.code == 0) {
      Navigator.of(context).pop(url);
    } else {
      ToastUtils.toast(TIM_t("头像更新失败，请重试"));
    }
  }

  Future<void> _pickFromDevice() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty) return;

    setState(() => _uploading = true);
    final result = await AvatarUploader.upload(path);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (!result.isSuccess) {
      ToastUtils.toast(_errorText(result.errorCode));
      return;
    }
    await _applyAvatar(result.url!);
  }

  Future<void> _useImageUrl() async {
    final url = await showProfileTextDialog(
      context: context,
      title: TIM_t("使用图片链接"),
      hint: "https://...",
      maxLength: 500,
    );
    if (url == null || url.isEmpty) return;
    if (!url.startsWith("http")) {
      ToastUtils.toast(TIM_t("请输入有效的图片链接"));
      return;
    }
    await _applyAvatar(url);
  }

  Future<void> _submitAvatar() async {
    if (_selectedUrl.isNotEmpty) {
      await _applyAvatar(_selectedUrl);
    }
  }

  Widget _customSection(BuildContext context, Color accent) {
    final onSurface = AppColors.onSurfaceOf(context);
    final weakText = AppColors.weakTextOf(context);
    final divider = AppColors.dividerOf(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(TIM_t("自定义头像"),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: weakText)),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Image.network(
                    _selectedUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.person,
                        size: 32, color: weakText),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!kIsWeb)
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickFromDevice,
                        icon: const Icon(Icons.upload_outlined, size: 16),
                        label: Text(TIM_t("从设备上传")),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(color: accent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _useImageUrl,
                      icon: const Icon(Icons.link, size: 16),
                      label: Text(TIM_t("图片链接")),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onSurface,
                        side: BorderSide(color: divider),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_uploading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accent)),
                const SizedBox(width: 8),
                Text(TIM_t("正在上传头像…"),
                    style: TextStyle(fontSize: 12, color: weakText)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final accent = theme.primaryColor ?? Theme.of(context).colorScheme.primary;
    final surface = AppColors.surfaceOf(context);
    final onSurface = AppColors.onSurfaceOf(context);
    final weakText = AppColors.weakTextOf(context);
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final crossAxisCount = MediaQuery.of(context).size.width >= 600 ? 6 : 4;

    Widget confirmButton() => TextButton(
          onPressed: _uploading ? null : _submitAvatar,
          child: Text(TIM_t("确定"),
              style: TextStyle(color: accent, fontSize: 15)),
        );

    return Scaffold(
      backgroundColor: surface,
      appBar: isWideScreen
          ? null
          : AppBar(
              iconTheme: IconThemeData(color: onSurface),
              backgroundColor: surface,
              foregroundColor: onSurface,
              elevation: 0,
              scrolledUnderElevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0.5),
                child:
                    Container(height: 0.5, color: AppColors.dividerOf(context)),
              ),
              title: Text(TIM_t("选择头像"),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: onSurface)),
              actions: [confirmButton()],
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWideScreen)
            AppBackBar(
              title: TIM_t("选择头像"),
              actions: [confirmButton()],
            ),
          _customSection(context, accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(TIM_t("预置头像"),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: weakText)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.avatarURLList.length,
              itemBuilder: (context, index) {
                final url = widget.avatarURLList[index];
                final selected = _selectedUrl == url;
                return GestureDetector(
                  onTap: () => setState(() => _selectedUrl = url),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.person, color: weakText),
                        ),
                        if (selected)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  size: 12, color: AppColors.onPrimary),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
