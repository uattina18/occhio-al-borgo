import 'package:flutter/material.dart';

class AppColors {
  // 🌞 Modalità chiara
  static const Color lightBackground = Color(0xFFe8e9ea);
  static const Color lightPrimary = Color(0xFF91be7e);
  static const Color lightAccent = Color(0xFF3a602a);
  static const Color lightText = Colors.black87;
  static const Color lightCard = Colors.white;

  // 🌙 Modalità scura
  static const Color darkBackground = Color(0xFF1C1C1E);
  static const Color darkPrimary = Color(0xFF91be7e);
  static const Color darkAccent = Color(0xFF577C4C);
  static const Color darkText = Colors.white;
  static const Color darkCard = Color(0xFF2C2C2E);

  // ⚪️ Colori neutri sempre disponibili
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // 🎨 Helpers contestuali per gestire tema chiaro/scuro
  static Color background(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkBackground : lightBackground;
  }

  static Color foreground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkText : lightText;
  }

  static Color card(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkCard : lightCard;
  }

  static Color accent(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkAccent : lightAccent;
  }

  static Color primary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkPrimary : lightPrimary;
  }

  static Color subtext(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? Colors.white70 : Colors.black54;
  }
}
