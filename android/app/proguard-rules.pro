-keep class com.tencent.** { *; }
-keep class com.baidu.** {*;}
-keep class vi.com.** {*;}
-keep class com.baidu.vi.** {*;}
#-keep class com.tencent.flutter.tuikit.** {*;}
-dontwarn com.baidu.**
# ffmpeg-android-java 在 build.gradle 里被排掉了，但插件的 Kotlin 还引用它的类；
# 不压这条警告，R8 会以 Missing class 直接失败。
-dontwarn com.github.hiteshsondhi88.**
# R8 打开后这些必须留着：SDK 用 Gson 和 Kotlin 反射，签名/注解被删就是运行时崩。
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
#-ignorewarnings
#-keep class com.hianalytics.android.**{*;}
#-keep class com.huawei.updatesdk.**{*;}
#-keep class com.huawei.hms.**{*;}
#-keep class com.xiaomi.**{*;}
#-dontwarn com.meizu.cloud.pushsdk.**
#-keep class com.meizu.cloud.pushsdk.**{*;}
#-dontwarn com.vivo.push.**
#-keep class com.vivo.push.**{*; }
#-keep class com.vivo.vms.**{*; }
#-keep public class * extends android.app.Service
#-keep class com.heytap.mcssdk.** {*;}
#-keep class com.heytap.msp.push.** { *;}
