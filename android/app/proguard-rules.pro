# ============================================================
# THIX ID — Règles ProGuard/R8
# ============================================================

# ---------- APPLICATION / ACTIVITIES ----------
-keep class com.thixhub.** { *; }
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver

# ---------- ATTRIBUTS ----------
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations, AnnotationDefault
-keepattributes SourceFile,LineNumberTable

# ---------- FLUTTER ----------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ---------- ML KIT ----------
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ---------- GOOGLE PLAY CORE ----------
-dontwarn com.google.android.play.core.**

# ---------- AGORA ----------
-keep class io.agora.** { *; }
-dontwarn io.agora.**
-keepclasseswithmembernames class * {
    native <methods>;
}

# ---------- FIREBASE / GMS ----------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---------- GSON ----------
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# ---------- PERMISSION_HANDLER ----------
-keep class com.baseflow.permissionhandler.** { *; }

# ---------- ENUM ----------
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ---------- PARCELABLE ----------
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# ---------- KOTLIN ----------
-keep class kotlin.Metadata { *; }

# ---------- OKHTTP / OKIO ----------
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
