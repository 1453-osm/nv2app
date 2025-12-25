# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Core rules
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Namaz Vaktim app specific rules
-keep class com.osm.NamazVaktim.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# (Android widget kaldırıldı)

# Keep method channel classes
-keep class * {
    @io.flutter.plugin.common.MethodChannel$Result *;
}

# Location services
-keep class * implements android.location.LocationListener { *; }

# Gson/JSON serialization (if used)
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Additional optimization rules
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# Remove Flutter debug code
-assumenosideeffects class io.flutter.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# Remove system logging
-assumenosideeffects class java.lang.System {
    public static void out.print*(...);
    public static void err.print*(...);
}

# Optimize enums
-optimizations !code/simplification/enum

# Genel Android optimizasyonları
-keep class * extends android.app.Service { *; }
-keep class * extends android.content.BroadcastReceiver { *; }
-keep class * extends android.appwidget.AppWidgetProvider { *; }

# Memory optimizasyonları
-keep class android.support.v4.** { *; }
-keep class androidx.** { *; }
-dontwarn android.support.v4.**
-dontwarn androidx.**

# Genel optimizasyonlar
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes LineNumberTable
-keepattributes SourceFile