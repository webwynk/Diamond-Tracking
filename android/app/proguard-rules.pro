# R8 rules for the release build.
#
# The old MapLibre rules are gone with MapLibre. Google Maps, Supabase and the
# other plugins ship their own consumer rules, so only project-wide rules live
# here. Add a rule only with a comment saying which crash it prevents.

# Flutter deferred components are not used; silence the missing Play Core classes.
-dontwarn com.google.android.play.core.**

# Keep native method signatures (JNI bridges in plugins).
-keepclasseswithmembernames class * {
    native <methods>;
}
