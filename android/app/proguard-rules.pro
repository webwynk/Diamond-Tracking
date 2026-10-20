# R8 rules for the release build.
# Critical: MapLibre GL Native uses JNI, reflection, and Gson serialization.
# Without these keep rules, R8 strips native bridge classes and crashes the app when opening maps.

# Flutter deferred components
-dontwarn com.google.android.play.core.**

# ==========================================
# MapLibre GL Native & Flutter Plugin Rules
# ==========================================

# Preserve MapLibre Android SDK core and JNI bindings
-keep class org.maplibre.android.** { *; }
-dontwarn org.maplibre.android.**

# Preserve MapLibre GL Flutter Plugin classes
-keep class org.maplibre.maplibregl.** { *; }
-dontwarn org.maplibre.maplibregl.**

# Compatibility namespace for Mapbox GL
-keep class com.mapbox.mapboxgl.** { *; }
-dontwarn com.mapbox.mapboxgl.**

# Preserve all native method signatures across libraries
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve MapView and custom view constructors invoked via reflection/inflation
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Preserve Parcelable classes (used for camera positions, coordinates, bounds)
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Preserve style, layer, and geometry property models
-keep class org.maplibre.android.style.** { *; }
-keep class org.maplibre.android.geometry.** { *; }

# Preserve Gson serialization if bundled by MapLibre
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Preserve annotations, signatures, and inner classes for JNI/reflection
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Preserve MapLibre Android resources
-keep class org.maplibre.android.R$* { *; }

# ==========================================
# Foreground Service & Location Plugins
# ==========================================
-keep class com.pravera.flutter_foreground_task.** { *; }
-dontwarn com.pravera.flutter_foreground_task.**
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

