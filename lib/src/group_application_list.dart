import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';

class GroupApplicationList extends StatefulWidget {
  /// group ID
  final String groupID;

  const GroupApplicationList({Key? key, required this.groupID})
      : super(key: key);

  @override
  State<GroupApplicationList> createState() => _GroupApplicationListState();
}

class _GroupApplicationListState extends State<GroupApplicationList> {
  final TUIChatGlobalModel model = serviceLocator<TUIChatGlobalModel>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  List<V2TimGroupApplication> groupApplicationList = [];
  final Map<int, String> _handled = {};

  @override
  void initState() {
    super.initState();
    groupApplicationList = model.groupApplicationList
        .where((item) => item.groupID == widget.groupID)
        .toList();
    for (int i = 0; i < groupApplicationList.length; i++) {
      final item = groupApplicationList[i];
      if (item.handleResult == 1) {
        _handled[i] = "accept";
      } else if (item.handleResult == 2) {
        _handled[i] = "reject";
      }
    }
  }

  String _getUserName(V2TimGroupApplication a) {
    if (a.fromUserNickName != null &&
        a.fromUserNickName!.isNotEmpty &&
        a.fromUserNickName != a.fromUser) {
      return "${a.fromUserNickName} (${a.fromUser})";
    }
    return a.fromUser ?? "";
  }

  String _getRequestMessage(V2TimGroupApplication a) {
    final msg = a.requestMsg ?? "";
    return TIM_t_para("验证消息: {{option2}}", "验证消息: $msg")(option2: msg);
  }

  Widget _item(
      BuildContext context, V2TimGroupApplication a, int index, TUITheme theme) {
    final status = _handled[index];
    final bool pending = status == null && a.handleStatus == 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: theme.weakBackgroundColor,
          border: Border(
              bottom: BorderSide(
                  color: theme.weakDividerColor ?? CommonColor.weakDividerColor))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: SizedBox(
              height: 40,
              width: 40,
              child: Avatar(
                  faceUrl: a.fromUserFaceUrl ?? "",
                  showName: a.fromUserNickName ?? a.fromUser ?? ""),
            ),
          ),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getUserName(a),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.darkTextColor),
              ),
              Text(
                _getRequestMessage(a),
                style: TextStyle(fontSize: 15, color: theme.weakTextColor),
              ),
            ],
          )),
          if (pending)
            Container(
              margin: const EdgeInsets.only(left: 8, right: 8),
              child: InkWell(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: theme.primaryColor,
                        border: Border.all(
                            width: 1,
                            color: theme.weakTextColor ??
                                CommonColor.weakTextColor)),
                    child: Text(
                      TIM_t("同意"),
                      style: const TextStyle(color: AppColors.onPrimary),
                    ),
                  ),
                  onTap: () async {
                    final res = await _groupServices.acceptGroupApplication(
                      groupID: a.groupID,
                      fromUser: a.fromUser!,
                      toUser: a.toUser!,
                      type: a.type,
                      addTime: a.addTime ?? 0,
                    );
                    if (res.code == 0) {
                      setState(() {
                        _handled[index] = "accept";
                      });
                      Future.delayed(const Duration(seconds: 1), () {
                        model.refreshGroupApplicationList();
                      });
                    }
                  }),
            ),
          if (pending)
            InkWell(
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: theme.weakBackgroundColor,
                    border: Border.all(
                        width: 1,
                        color: theme.weakTextColor ?? CommonColor.weakTextColor)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  TIM_t("拒绝"),
                  style: TextStyle(color: theme.primaryColor),
                ),
              ),
              onTap: () async {
                final res = await _groupServices.refuseGroupApplication(
                    addTime: a.addTime!,
                    groupID: a.groupID,
                    fromUser: a.fromUser!,
                    toUser: a.toUser!,
                    type: GroupApplicationTypeEnum.values[a.type]);
                if (res.code == 0) {
                  setState(() {
                    _handled[index] = "reject";
                  });
                  Future.delayed(const Duration(seconds: 1), () {
                    model.refreshGroupApplicationList();
                  });
                }
              },
            ),
          if (status == "accept" || a.handleResult == 1)
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Text(
                TIM_t("已同意"),
                style: TextStyle(fontSize: 15, color: theme.weakTextColor),
              ),
            ),
          if (status == "reject" || a.handleResult == 2)
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Text(
                TIM_t("已拒绝"),
                style: TextStyle(fontSize: 15, color: theme.weakTextColor),
              ),
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Scaffold(
      backgroundColor: theme.weakBackgroundColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: AppColors.onPrimary,
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        title: Text(
          TIM_t("进群申请列表"),
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 17,
          ),
        ),
      ),
      body: groupApplicationList.isEmpty
          ? Center(
              child: Text(TIM_t("暂无申请"),
                  style: TextStyle(color: theme.weakTextColor)),
            )
          : ListView.builder(
              itemCount: groupApplicationList.length,
              itemBuilder: (context, index) =>
                  _item(context, groupApplicationList[index], index, theme),
            ),
    );
  }
}
