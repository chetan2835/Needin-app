# ══════════════════════════════════════════════════════════════════════
# Needin App — ProGuard / R8 Rules
# ══════════════════════════════════════════════════════════════════════
# Flutter's Dart code is AOT-compiled and runs in its own VM — R8 does
# NOT touch it. These rules only protect the Android-side plugin wrappers
# and third-party JVM/Kotlin libraries from being incorrectly stripped.
# ══════════════════════════════════════════════════════════════════════

# ── Google Maps ───────────────────────────────────────────────────────
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.maps.android.** { *; }

# ── Firebase ──────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Supabase / OkHttp / Ktor (HTTP client) ────────────────────────────
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Razorpay ──────────────────────────────────────────────────────────
-keepattributes *Annotation*
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keep class org.json.** { *; }

# ── Image Picker / File Handling ──────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }

# ── Flutter local notifications ───────────────────────────────────────
-keep class com.dexterous.** { *; }

# ── Geolocator ────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }

# ── Flutter Secure Storage ────────────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ── Share Plus ────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }

# ── General: Preserve line numbers for crash reports ──────────────────
# This keeps source file names and line numbers visible in stack traces
# without retaining the full debug symbol tables from native .so files.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── Suppress known harmless warnings ──────────────────────────────────
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
