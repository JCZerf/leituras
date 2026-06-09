# Keep all ML Kit classes and prevent them from being removed/obfuscated
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Specific rules for text recognition languages
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
