# Flutter wrapper & embedding keep rules for Android Release (R8)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.example.mikrotik_cards_app.** { *; }
-dontwarn io.flutter.embedding.**
