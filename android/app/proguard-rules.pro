# ============================================================
# THIX ID — Règles ProGuard/R8
# ============================================================

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
# ML Kit Text Recognition — options de langue (chargées dynamiquement,
# non détectées automatiquement par R8)
# ==========================================
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# ML Kit — classes génériques (précaution pour d'autres modules ML Kit
# comme genai_image_description, barcode, face, etc.)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ==========================================
# Google Play Core (requis par certains plugins Flutter en mode release)
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
# GSON / JSON (sérialisation utilisée en interne par plusieurs SDKs)
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
# ENUM (protège tous les enums utilisés par réflexion — Dart platform
# channels, Supabase, Agora)
# ==========================================
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ==========================================
# PARCELABLE (nécessaire pour les plugins natifs utilisant Android IPC)
# ==========================================
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# ==========================================
# KOTLIN METADATA (évite les erreurs de réflexion Kotlin, notamment
# avec Riverpod codegen et les plugins Kotlin natifs)
# ==========================================
-keep class kotlin.Metadata { *; }
-keepattributes RuntimeVisibleAnnotations, AnnotationDefault

# ==========================================
# CACHED_NETWORK_IMAGE / OkHttp (utilisé en interne par plusieurs plugins
# réseau Flutter)
# ==========================================
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
