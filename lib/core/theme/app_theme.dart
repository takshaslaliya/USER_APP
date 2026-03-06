import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static String currentThemeName = 'purple';

  // Primary Colors (Dynamic) - Purple Default
  static Color primary = Color(0xFFA855F7);
  static Color primaryLight = Color(0xFFD8B4FE);
  static Color primaryDark = Color(0xFF3B0764);

  // Gradients (Dynamic)
  static List<Color> primaryGradient = const [
    Color(0xFFD8B4FE),
    Color(0xFFA855F7),
  ];
  static const List<Color> introGradient = [
    Color(0xFF031514),
    Color(0xFF053230),
    Color(0xFF031514),
  ];

  // Light theme (Laser Aqua Blue style - light mode)
  static Color lightBg = Color(0xFFE8F6F6); // Soft cyan tinted background
  static Color lightSurface = Color(0xFFFFFFFF); // Pure white cards/surface
  static Color lightSurfaceVariant = Color(0xFFD4EBEB); // Subtle cyan variation

  // Text Colors
  static Color lightText = Color(0xFF1D3A44); // Strong Dark Teal for text
  static Color lightSubtext = Color(0xFF5E7A81); // Muted teal-grey

  // Subtle drop shadows
  static Color softShadowColor = Color(0x0C032221); // Teal tinted shadow
  static Color neoLightShadow = Colors.transparent;
  static Color neoDarkShadow = Colors.transparent;

  static Color bgGradientLightTop = Color(0xFFF3FBFB);
  static Color bgGradientLightBottom = Color(0xFFE8F6F6);

  // Dark theme
  static Color darkBg = Color(0xFF021211);
  static Color darkSurface = Color(0xFF032221);
  static Color darkSurfaceVariant = Color(0xFF06413F);
  static Color darkText = Color(0xFFE8F6F6);
  static Color darkSubtext = Color(0xFF84A8A6);

  static Color bgGradientDarkTop = Color(0xFF042624);
  static Color bgGradientDarkBottom = Color(0xFF010A0A);

  // Status
  static Color paid = Color(0xFF1CB0A0);
  static Color paidBg = Color(0xFFE5FFFC);
  static Color pending = Color(0xFFF59E0B);
  static Color pendingBg = Color(0xFFFEF3C7);
  static Color error = Color(0xFFEF4444);

  // Social
  static Color whatsapp = Color(0xFF25D366);
}

class AppTheme {
  static const double borderRadius = 16.0;
  static const double padding = 28.0;
  static const double paddingSmall = 12.0;

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        surface: AppColors.lightSurface,
        onPrimary: Colors.white,
        onSurface: AppColors.lightText,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightText,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.lightText,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.lightText,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.lightText,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.lightSubtext,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightSurfaceVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightSurfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.poppins(
          color: AppColors.lightSubtext,
          fontSize: 14,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.lightText),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
        ),
      ),
      dividerColor: AppColors.lightSurfaceVariant,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.darkSurface,
        onPrimary: AppColors.primaryDark,
        onSurface: AppColors.darkText,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.darkText,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.darkText,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.darkSubtext,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.darkSurfaceVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.darkSurfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.poppins(
          color: AppColors.darkSubtext,
          fontSize: 14,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.darkText),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
      ),
      dividerColor: AppColors.darkSurfaceVariant,
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isSystem => _themeMode == ThemeMode.system;

  ThemeProvider({ThemeMode? initialMode, String? initialThemeName}) {
    if (initialMode != null) _themeMode = initialMode;
    if (initialThemeName != null) {
      setThemeColor(initialThemeName, save: false);
    } else {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final modeStr = prefs.getString('themeMode') ?? 'system';
      if (modeStr == 'dark')
        _themeMode = ThemeMode.dark;
      else if (modeStr == 'light')
        _themeMode = ThemeMode.light;
      else
        _themeMode = ThemeMode.system;

      final savedTheme = prefs.getString('themeName') ?? 'purple';
      setThemeColor(savedTheme, save: false);
    } catch (e) {
      debugPrint('Error loading theme settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String modeStr = 'system';
      if (_themeMode == ThemeMode.dark)
        modeStr = 'dark';
      else if (_themeMode == ThemeMode.light)
        modeStr = 'light';

      await prefs.setString('themeMode', modeStr);
      await prefs.setString('themeName', AppColors.currentThemeName);
    } catch (e) {
      debugPrint('Error saving theme settings: $e');
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void toggle() {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    _saveSettings();
    notifyListeners();
  }

  void setThemeColor(String colorTheme, {bool save = true}) {
    AppColors.currentThemeName = colorTheme;

    switch (colorTheme) {
      case 'purple':
        AppColors.primary = Color(0xFFA855F7);
        AppColors.primaryLight = Color(0xFFD8B4FE);
        AppColors.primaryDark = Color(0xFF3B0764);
        AppColors.primaryGradient = const [
          Color(0xFFD8B4FE),
          Color(0xFFA855F7),
        ];
        break;
      case 'orange':
        AppColors.primary = Color(0xFFF97316);
        AppColors.primaryLight = Color(0xFFFDBA74);
        AppColors.primaryDark = Color(0xFF431407);
        AppColors.primaryGradient = const [
          Color(0xFFFDBA74),
          Color(0xFFF97316),
        ];
        break;
      case 'red':
        AppColors.primary = Color(0xFFEF4444);
        AppColors.primaryLight = Color(0xFFFCA5A5);
        AppColors.primaryDark = Color(0xFF450A0A);
        AppColors.primaryGradient = const [
          Color(0xFFFCA5A5),
          Color(0xFFEF4444),
        ];
        break;
      case 'green':
        AppColors.primary = Color(0xFF22C55E);
        AppColors.primaryLight = Color(0xFF86EFAC);
        AppColors.primaryDark = Color(0xFF052E16);
        AppColors.primaryGradient = const [
          Color(0xFF86EFAC),
          Color(0xFF22C55E),
        ];
        break;
      case 'yellow':
        AppColors.primary = Color(0xFFEAB308);
        AppColors.primaryLight = Color(0xFFFDE047);
        AppColors.primaryDark = Color(0xFF422006);
        AppColors.primaryGradient = const [
          Color(0xFFFDE047),
          Color(0xFFEAB308),
        ];
        break;
      default:
        // Use purple as default/fallback
        AppColors.primary = Color(0xFFA855F7);
        AppColors.primaryLight = Color(0xFFD8B4FE);
        AppColors.primaryDark = Color(0xFF3B0764);
        AppColors.primaryGradient = const [
          Color(0xFFD8B4FE),
          Color(0xFFA855F7),
        ];
        break;
    }
    _updateBackgroundTints();
    if (save) _saveSettings();
    notifyListeners();
  }

  void _updateBackgroundTints() {
    final Color p = AppColors.primary;

    // Derive a very light pastel of the primary for light mode backgrounds
    final int r = (p.r * 255).round();
    final int g = (p.g * 255).round();
    final int b = (p.b * 255).round();

    // Light bg: mix primary with white heavily (5% primary, 95% white)
    AppColors.lightBg = Color.fromARGB(
      255,
      _mix(r, 243, 0.08),
      _mix(g, 248, 0.08),
      _mix(b, 248, 0.08),
    );
    AppColors.lightSurfaceVariant = Color.fromARGB(
      255,
      _mix(r, 220, 0.12),
      _mix(g, 235, 0.12),
      _mix(b, 235, 0.12),
    );
    AppColors.bgGradientLightTop = Color.fromARGB(
      255,
      _mix(r, 250, 0.06),
      _mix(g, 253, 0.06),
      _mix(b, 253, 0.06),
    );
    AppColors.bgGradientLightBottom = AppColors.lightBg;

    // Dark bg: mix primary with near-black (8% primary, 92% dark)
    AppColors.darkBg = Color.fromARGB(
      255,
      _mix(r, 4, 0.08),
      _mix(g, 12, 0.08),
      _mix(b, 14, 0.08),
    );
    AppColors.darkSurface = Color.fromARGB(
      255,
      _mix(r, 6, 0.12),
      _mix(g, 20, 0.12),
      _mix(b, 22, 0.12),
    );
    AppColors.darkSurfaceVariant = Color.fromARGB(
      255,
      _mix(r, 12, 0.18),
      _mix(g, 38, 0.18),
      _mix(b, 42, 0.18),
    );
    AppColors.bgGradientDarkTop = Color.fromARGB(
      255,
      _mix(r, 8, 0.10),
      _mix(g, 24, 0.10),
      _mix(b, 28, 0.10),
    );
    AppColors.bgGradientDarkBottom = AppColors.darkBg;
  }

  int _mix(int primary, int base, double ratio) {
    return (primary * ratio + base * (1 - ratio)).round().clamp(0, 255);
  }
}
