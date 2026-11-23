import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_model.dart';

/// Controlador global del tema (claro / oscuro).
///
/// Sigue al sistema hasta que el usuario elige con el botón sol/luna; la
/// elección se guarda en SharedPreferences.
class AppThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode');
    themeMode.value = switch (isDark) {
      true => ThemeMode.dark,
      false => ThemeMode.light,
      null => ThemeMode.system,
    };
  }

  static Future<void> toggleTheme() async {
    final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
    themeMode.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', newMode == ThemeMode.dark);
  }

  static bool get isDark {
    if (themeMode.value == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return themeMode.value == ThemeMode.dark;
  }
}

/// Paleta "invernadero" (SKILL.md de la PWA, skill greentech-invernadero-ui):
/// fondo claro u oscuro, verde hoja para lo que está en rango y bermellón
/// solo para lo crítico. Los nombres anteriores se conservan para no tocar
/// cada pantalla.
class AppColors {
  AppColors._();

  // Marca y semáforo (relleno: puntos, barras, íconos grandes; no texto chico)
  static const Color primary = Color(0xFF729C51); // verde hoja
  static const Color primaryDark = Color(0xFF456B2C);
  /// Acento para íconos y botones; blanco encima da 5.4:1.
  static const Color secondary = Color(0xFF4E7433);
  static const Color secondaryDark = Color(0xFF3D5A27);
  static const Color mintAccent = Color(0xFFA9CB8A);
  static const Color accentOrange = Color(0xFFE3A21A); // atención
  static const Color critico = Color(0xFFEB5011); // bermellón, solo crítico
  static const Color mist = Color(0xFFC7DEED);

  // Modo claro
  static const Color background = Color(0xFFEEF1EA);
  static const Color surface = Color(0xFFF7F8F4);
  static const Color well = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0A0909);
  static const Color textPrimary = Color(0xFF0A0909);
  /// 5.8:1 sobre [surface].
  static const Color textSecondary = Color(0xFF5B6356);
  static const Color border = Color(0xFFDDE3D6);

  // Modo oscuro (negro verdoso, nunca negro puro)
  static const Color darkBackground = Color(0xFF0F1310);
  static const Color darkSurface = Color(0xFF1A201B);
  static const Color darkWell = Color(0xFF1F261F);
  static const Color darkInk = Color(0xFFEEF2EA);
  static const Color darkTextPrimary = Color(0xFFEEF2EA);
  /// 7.1:1 sobre [darkSurface].
  static const Color darkTextSecondary = Color(0xFFA3AD9C);
  static const Color darkBorder = Color(0xFF2C362B);

  /// Chip sólido de Crítico: fondo y texto (en oscuro el texto es oscuro).
  static Color criticoSolido({required bool isDark}) =>
      isDark ? const Color(0xFFFF7A3D) : const Color(0xFFC2410C);
  static Color sobreCritico({required bool isDark}) =>
      isDark ? darkBackground : Colors.white;

  static Color forEstado(EstadoNivel estado) {
    switch (estado) {
      case EstadoNivel.normal:
        return primary;
      case EstadoNivel.alerta:
        return accentOrange;
      case EstadoNivel.critico:
        return critico;
    }
  }

  // Texto e íconos de estado con contraste WCAG AA (≥ 4.5:1) sobre las
  // tarjetas, también sobre la píldora teñida con el mismo color. Los
  // colores de marca de arriba (primary, accentOrange, critico) no llegan
  // a 4.5:1 sobre el fondo claro, así que no se usan para texto pequeño.
  // Contraste en claro sobre #F7F8F4 / en oscuro sobre #1A201B:
  static const Color _okLight = Color(0xFF456B2C); // 5.8:1
  static const Color _warnLight = Color(0xFF7A5200); // 6.5:1
  static const Color _critLight = Color(0xFFA8380A); // 6.1:1
  static const Color _staleLight = Color(0xFF5E665A); // 5.6:1
  static const Color _okDark = Color(0xFFA9CB8A); // 9.2:1
  static const Color _warnDark = Color(0xFFF5C46A); // 10.3:1
  static const Color _critDark = Color(0xFFFF8A57); // 7.1:1
  static const Color _staleDark = Color(0xFF9AA595); // 6.5:1

  /// Color para texto, íconos y bordes de estado (semáforo).
  static Color estadoTexto(EstadoNivel estado, {required bool isDark}) =>
      switch (estado) {
        EstadoNivel.normal => isDark ? _okDark : _okLight,
        EstadoNivel.alerta => isDark ? _warnDark : _warnLight,
        EstadoNivel.critico => isDark ? _critDark : _critLight,
      };

  /// Gris para lecturas viejas o ausentes.
  static Color sinDatos({required bool isDark}) =>
      isDark ? _staleDark : _staleLight;

  static IconData iconForEstado(EstadoNivel estado) {
    switch (estado) {
      case EstadoNivel.normal:
        return Icons.check_circle_rounded;
      case EstadoNivel.alerta:
        return Icons.warning_rounded;
      case EstadoNivel.critico:
        return Icons.report_rounded;
    }
  }

  static String labelForEstado(EstadoNivel estado) {
    switch (estado) {
      case EstadoNivel.normal:
        return 'Normal';
      case EstadoNivel.alerta:
        return 'Atención';
      case EstadoNivel.critico:
        return 'Crítico';
    }
  }
}

/// Tema de Material 3 a partir de la paleta. [dark] elige los valores.
ThemeData _buildTheme({required bool dark}) {
  final bg = dark ? AppColors.darkBackground : AppColors.background;
  final surface = dark ? AppColors.darkSurface : AppColors.surface;
  final text = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  final text2 = dark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  final border = dark ? AppColors.darkBorder : AppColors.border;
  final ink = dark ? AppColors.darkInk : AppColors.ink;
  final onInk = dark ? AppColors.darkBackground : Colors.white;

  final colorScheme = (dark ? const ColorScheme.dark() : const ColorScheme.light())
      .copyWith(
    primary: dark ? AppColors.mintAccent : AppColors.secondary,
    onPrimary: dark ? AppColors.darkBackground : Colors.white,
    secondary: AppColors.primary,
    onSecondary: dark ? AppColors.darkBackground : Colors.white,
    surface: surface,
    onSurface: text,
    onSurfaceVariant: text2,
    outline: border,
    outlineVariant: border,
    error: AppColors.criticoSolido(isDark: dark),
    onError: AppColors.sobreCritico(isDark: dark),
    surfaceContainerHighest: dark ? AppColors.darkWell : AppColors.well,
  );

  final base = GoogleFonts.plusJakartaSansTextTheme(
      dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: bg,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: text),
      actionsIconTheme: IconThemeData(color: text),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: border),
      ),
      margin: EdgeInsets.zero,
    ),
    // Primario: negro (o claro en oscuro). El verde no es color de botón:
    // significa "en rango".
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: onInk,
        minimumSize: const Size(48, 48),
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: onInk,
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: ink,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? onInk : text2,
          )),
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w600, color: text)),
    ),
    dividerTheme: DividerThemeData(color: border, space: 1),
    textTheme: base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: text,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: text,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: text2,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: text2,
      ),
    ),
  );
}

/// Tema de Material 3 en modo claro.
ThemeData buildAppTheme() => _buildTheme(dark: false);

/// Tema de Material 3 en modo oscuro.
ThemeData buildDarkAppTheme() => _buildTheme(dark: true);
