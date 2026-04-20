import 'package:flutter/material.dart';

class AppTheme {

  static const primaryColor = Color(0xfff27f0d);

  static ThemeData lightTheme = ThemeData(
    fontFamily: "PlusJakartaSans",
    primaryColor: primaryColor,
    scaffoldBackgroundColor: Color(0xfff8f7f5),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    fontFamily: "PlusJakartaSans",
    brightness: Brightness.dark,
  );

}