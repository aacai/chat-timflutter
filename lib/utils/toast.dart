import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'commonUtils.dart';

class ToastUtils {
  static FToast? fToast;

  static void init(BuildContext context){
    if(fToast == null){
      fToast = FToast();
      fToast!.init(context);
    }
  }

  static void toast(String msg) {
    // SDK 回调不带 BuildContext，FToast 的 context 一旦失效会在
    // MediaQuery.of 里抛空指针；改用原生 toast，不依赖 widget 树。
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      textColor: AppColors.onPrimary,
      fontSize: 14,
      backgroundColor: Colors.black54,
    );
  }

  static void toastError(int code, String desc) {
    Fluttertoast.showToast(
      msg: "code:$code,desc:$desc",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      textColor: AppColors.onPrimary,
      fontSize: CommonUtils.adaptFontSize(20),
      backgroundColor: Colors.black,
    );
  }

  static void log(Object? data) {
    bool prod =
        const bool.fromEnvironment('ISPRODUCT_ENV', defaultValue: false);
    if (!prod) {
      // ignore: avoid_print
      print("===================================");
      // ignore: avoid_print
      print("IM_DEMO_PRINT:$data");
      // ignore: avoid_print
      print("===================================");
    } else {}
  }
}
