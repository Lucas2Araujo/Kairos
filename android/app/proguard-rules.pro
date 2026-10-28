# Flutter baseline rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.** { *; }

# SharedPreferences & Pigeon native interop rules
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class dev.flutter.plugins.sharedpreferences.** { *; }
-keep class * implements io.flutter.plugins.sharedpreferences.** { *; }

# Kotlin coroutines and method signatures (preserves Continuation parameter)
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.jvm.functions.** { *; }
-keep class * implements kotlin.coroutines.Continuation { *; }
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses

# Google Sign-In & Play Services
-keep class com.google.android.gms.auth.api.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class androidx.credentials.** { *; }

# SQLite
-keep class org.sqlite.** { *; }
