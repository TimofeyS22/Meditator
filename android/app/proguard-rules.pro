# Home screen widget
-keep class com.meditatorapp.meditator.MeditatorWidget { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep JSON serialization
-keepattributes *Annotation*
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Health Connect
-keep class androidx.health.connect.** { *; }
-keep class androidx.health.platform.** { *; }

# just_audio
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
-keep class com.ryanheise.just_audio.** { *; }

# Dio / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
