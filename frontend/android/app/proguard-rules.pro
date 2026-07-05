# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# dio
-keep class com.dio.** { *; }
-dontwarn com.dio.**

# OkHttp / Okio (dio 依赖)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-keepattributes Signature
-keepattributes *Annotation*

# Retrofit (若用到)
-keep class retrofit2.** { *; }
-keepattributes Exceptions

# Gson / JSON 反射
-keepattributes *Annotation*
-keepclassmembers,allowshrinking,allowoptimization class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.** { *; }

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# connectivity_plus
-keep class com.example.connectivity_plus.** { *; }
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# cached_network_image / flutter_cache_manager
-keep class io.flutter.plugins.image.** { *; }

# video_player (exoplayer)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Kotlin 协程
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler
-keepclassmembers class ** {
    @kotlinx.coroutines.ExperimentalCoroutinesApi public *;
}
-keepattributes RuntimeVisibleAnnotations
-keepclassmembers class ** {
    public <init>(kotlin.coroutines.Continuation);
}

# Kotlin 反射
-keep class kotlin.** { *; }
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.**

# 通用
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes Signature

# 调试信息保留
-keepattributes SourceFile,LineNumberTable

# AGP 8.x + R8 严格模式兼容：Google Play Core 可选类
# 这些类仅在 Google Play Dynamic Delivery 环境中需要，缺失是正常的
-ignorewarnings
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
