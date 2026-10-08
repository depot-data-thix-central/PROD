# ═══════════════════════════════════════════════════════════════
# R8 / ProGuard — THIX ID (version optimisée pour full mode)
# ═══════════════════════════════════════════════════════════════
# Principe : les plugins Flutter modernes injectent leurs propres
# règles via consumer-rules.pro. On ne garde QUE ce qui casse
# vraiment (entry points Android, JNI, réflexion spécifique).
# ═══════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────
# ENTRY POINTS ANDROID (indispensables, système Android les cherche par réflexion)
# ───────────────────────────────────────────────────────────────
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference

# ───────────────────────────────────────────────────────────────
# MÉTADONNÉES (nécessaires pour stack traces lisibles + sérialisation)
# ───────────────────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations, AnnotationDefault
-keepattributes SourceFile, LineNumberTable
-keepattributes EnclosingMethod, InnerClasses
-renamesourcefileattribute SourceFile

# ───────────────────────────────────────────────────────────────
# JNI / NATIVES (Agora, SQLite, etc. : méthodes appelées depuis C/C++)
# ───────────────────────────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ───────────────────────────────────────────────────────────────
# ENUMS (accédés par réflexion : valueOf, values)
# ───────────────────────────────────────────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ───────────────────────────────────────────────────────────────
# PARCELABLE / SERIALIZABLE
# ───────────────────────────────────────────────────────────────
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

# ───────────────────────────────────────────────────────────────
# KOTLIN METADATA (nécessaire pour la réflexion Kotlin / Moshi / Serialization)
# ───────────────────────────────────────────────────────────────
-keep class kotlin.Metadata { *; }

# ───────────────────────────────────────────────────────────────
# AGORA RTC (SDK natif complexe, beaucoup de réflexion + JNI)
# On garde TOUT pour Agora : trop de points d'entrée cachés.
# ───────────────────────────────────────────────────────────────
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# ───────────────────────────────────────────────────────────────
# ML KIT TEXT RECOGNITION (utilisé pour scan OCR)
# ───────────────────────────────────────────────────────────────
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ───────────────────────────────────────────────────────────────
# AVERTISSEMENTS À IGNORER (bibliothèques optionnelles non utilisées)
# ───────────────────────────────────────────────────────────────
-dontwarn com.google.android.play.core.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn sun.misc.**
-dontwarn org.codehaus.mojo.**

# ═══════════════════════════════════════════════════════════════
# ❌ SUPPRIMÉ (déjà géré par consumer-rules des plugins) :
#   io.flutter, io.flutter.plugins
#   com.google.firebase, com.google.android.gms
#   com.google.gson
#   com.baseflow.permissionhandler
#   okhttp3
#
# ❌ SUPPRIMÉ (empêchait toute optimisation du code métier) :
#   com.thixhub.** { *; }
# ═══════════════════════════════════════════════════════════════
