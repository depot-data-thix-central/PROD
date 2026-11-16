# ═══════════════════════════════════════════════════════════════
# R8 / ProGuard — THIX ID (Version Équilibrée : Safe & Optimized)
# ═══════════════════════════════════════════════════════════════
# Objectif : Stabilité pour les appels/notifs (Fichier 1) + 
#            Optimisation de la taille (Fichier 2).
# ═══════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────
# 1. ENTRY POINTS ANDROID
# ───────────────────────────────────────────────────────────────
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference

# ───────────────────────────────────────────────────────────────
# 2. MÉTADONNÉES
# ───────────────────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations, AnnotationDefault
-keepattributes SourceFile, LineNumberTable
-keepattributes EnclosingMethod, InnerClasses
-renamesourcefileattribute SourceFile

# ───────────────────────────────────────────────────────────────
# 3. JNI, ENUMS, PARCELABLE, KOTLIN
# ───────────────────────────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

-keep class kotlin.Metadata { *; }

# ───────────────────────────────────────────────────────────────
# 4. SDKS NATIFS CRITIQUES (Agora, ML Kit)
# ───────────────────────────────────────────────────────────────
-keep class io.agora.** { *; }
-dontwarn io.agora.**

-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ───────────────────────────────────────────────────────────────
# 5. PLUGINS NOTIFICATIONS / APPELS (Stabilité garantie)
# ───────────────────────────────────────────────────────────────
-keep class com.dexterous.** { *; }
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ───────────────────────────────────────────────────────────────
# 6. GSON (Sérialisation JSON pour le chat/API)
# ───────────────────────────────────────────────────────────────
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ───────────────────────────────────────────────────────────────
# 7. CODE MÉTIER THIX ID (L'équilibre parfait)
# ───────────────────────────────────────────────────────────────
# On autorise R8 à optimiser le code, SAUF :
# - Les classes annotées @Keep
# - Les modèles de données (si tu utilises Gson, remplace "models" par ton vrai dossier, ex: "com.thixhub.data.models.**")
-keep @androidx.annotation.Keep class * { *; }
-keep class com.thixhub.models.** { *; }
-keep class com.thixhub.data.dto.** { *; }

# Protège les champs Gson dans tout le code métier
-keepclassmembers class com.thixhub.** {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ───────────────────────────────────────────────────────────────
# 8. AVERTISSEMENTS À IGNORER
# ───────────────────────────────────────────────────────────────
-dontwarn com.google.android.play.core.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn sun.misc.**
-dontwarn org.codehaus.mojo.**
