# ============================================================
# THIX ID — Règles ProGuard/R8
# ============================================================

# ==========================================
# APPLICATION ENTRY POINT & ACTIVITIES
# (Empêche la suppression/renommage de la MainActivity)
# ==========================================
-keep class com.thixhub.MainActivity { *; }
-keep public class * extends android.app.Activity

# ==========================================
# FLUTTER CORE
# ==========================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ==========================================
# ML Kit Text Recognition — options de langue
# ==========================================
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# ML Kit — classes génériques
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ==========================================
# Google Play Core
# ==========================================
-dontwarn com.google.android.play.core.**

# ==========================================
# AGORA RTC ENGINE (live streaming)
# ==========================================
-keep class io.agora.** { *; }
-dontwarn io.agora.**
-keepclasseswithmembernames class * {
    native <methods>;
}

# ==========================================
# SUPABASE / GOTRUE / POSTGREST / REALTIME
# ==========================================
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**

# ==========================================
# FIREBASE (google-services)
# ==========================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ==========================================
# GSON / JSON
# ==========================================
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# ==========================================
# PERMISSION_HANDLER
# ==========================================
-keep class com.baseflow.permissionhandler.** { *; }

# ==========================================
# ENUM
# ==========================================
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ==========================================
# PARCELABLE
# ==========================================
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# ==========================================
# KOTLIN METADATA
# ==========================================
-keep class kotlin.Metadata { *; }
-keepattributes RuntimeVisibleAnnotations, AnnotationDefault

# ==========================================
# CACHED_NETWORK_IMAGE / OkHttp
# ==========================================
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
