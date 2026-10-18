# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.** { *; }

# Pigeon generated code
-keep class dev.flutter.pigeon.** { *; }
-keepclassmembers class dev.flutter.pigeon.** { *; }

# Shared Preferences plugin & JNI methods
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** { *; }

# Preserve Kotlin coroutines continuation interfaces used by suspend functions over JNI
-keep class kotlin.coroutines.** { *; }
-keepclassmembers class kotlin.coroutines.** { *; }
-keepclassmembers class * {
    *** *(..., kotlin.coroutines.Continuation);
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
