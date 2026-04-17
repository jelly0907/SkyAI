# Retrofit
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions

# OkHttp
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# Hilt
-keep class dagger.** { *; }
-keep class javax.inject.** { *; }
-keep class com.google.dagger.** { *; }

# Keep data classes used for serialization
-keep class com.skyai.app.data.model.** { *; }

# Coroutines
-keepattributes *Annotation*
-keep class kotlinx.coroutines.** { *; }

# Material 3
-keep class androidx.compose.material3.** { *; }
