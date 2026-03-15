import 'package:flutter/material.dart';

class AppColors {
  // Status semantic colors
  static const Color criticalBg = Color(0xFFFCEBEB);
  static const Color criticalText = Color(0xFFA32D2D);
  static const Color criticalBorder = Color(0xFFA32D2D);

  static const Color warningBg = Color(0xFFFAEEDA);
  static const Color warningText = Color(0xFF854F0B);
  static const Color warningBorder = Color(0xFF854F0B);

  static const Color okBg = Color(0xFFEAF3DE);
  static const Color okText = Color(0xFF3B6D11);
  static const Color okBorder = Color(0xFF3B6D11);

  static const Color aiActionBg = Color(0xFFE6F1FB);
  static const Color aiActionText = Color(0xFF185FA5);
  static const Color aiActionBorder = Color(0xFF185FA5);

  // Role identity
  static const Color parentRoleBg = Color(0xFFEEEDFE);
  static const Color parentRoleText = Color(0xFF3C3489);
  static const Color parentRoleBorder = Color(0xFFAFA9EC);

  static const Color childRoleBg = Color(0xFFEAF3DE);
  static const Color childRoleText = Color(0xFF27500A);
  static const Color childRoleBorder = Color(0xFF97C459);

  // Brand
  static const Color brandPrimary = Color(0xFF185FA5);
  static const Color brandDark = Color(0xFF042C53);

  // Pill progress bars
  static const Color pillFull = Color(0xFF3B6D11);
  static const Color pillLow = Color(0xFFA32D2D);
  static const Color pillPending = Color(0xFF185FA5);

  // Misc
  static const Color phoneFrame = Color(0xFF2C2C2A);
}

class AppTextStyles {
  // Senior App — larger for elderly (minimum 14px rule)
  static const TextStyle seniorTitle =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
  static const TextStyle seniorBody = TextStyle(fontSize: 14);
  static const TextStyle seniorLabel =
      TextStyle(fontSize: 12, color: Color(0xFF64748B));

  // Family App / Web
  static const TextStyle title =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const TextStyle body = TextStyle(fontSize: 12);
  static const TextStyle label =
      TextStyle(fontSize: 10, color: Color(0xFF64748B));
  static const TextStyle micro =
      TextStyle(fontSize: 8, color: Color(0xFF94A3B8));
}

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brandPrimary),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brandDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}
