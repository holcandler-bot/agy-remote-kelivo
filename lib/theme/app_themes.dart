import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

/// Kelivo Android FontWeight normalization (`app_font_weights.dart`).
/// Prevents CJK characters from looking bloated on Android system fonts.
abstract final class AppFontWeights {
  static bool get _isAndroid =>
      defaultTargetPlatform == TargetPlatform.android;

  static FontWeight get regular => FontWeight.w400;
  static FontWeight get medium =>
      _isAndroid ? FontWeight.w400 : FontWeight.w500;
  static FontWeight get emphasis =>
      _isAndroid ? FontWeight.w500 : FontWeight.w600;
  static FontWeight get semibold =>
      _isAndroid ? FontWeight.w500 : FontWeight.w600;
  static FontWeight get bold =>
      _isAndroid ? FontWeight.w500 : FontWeight.w700;
}

/// Kelivo 4-level Surface Ladder (`surface_ladder.dart`).
@immutable
class SurfaceLadder extends ThemeExtension<SurfaceLadder> {
  const SurfaceLadder({
    required this.l0Canvas,
    required this.l1Elevated,
    required this.l2Card,
    required this.l3Floating,
  });

  final Color l0Canvas;
  final Color l1Elevated;
  final Color l2Card;
  final Color l3Floating;

  factory SurfaceLadder.fromScheme(
    ColorScheme cs, {
    required Brightness brightness,
    bool isFrostGray = false,
  }) {
    if (isFrostGray) {
      return brightness == Brightness.dark
          ? const SurfaceLadder(
              l0Canvas: Color(0xFF0A0A0B),
              l1Elevated: Color(0xFF141416),
              l2Card: Color(0xFF1E1E21),
              l3Floating: Color(0xFF28282C),
            )
          : const SurfaceLadder(
              l0Canvas: Color(0xFFFFFFFF),
              l1Elevated: Color(0xFFF4F5F7),
              l2Card: Color(0xFFECEEF1),
              l3Floating: Color(0xFFE3E6EA),
            );
    }
    return SurfaceLadder(
      l0Canvas: cs.surface,
      l1Elevated: Color.alphaBlend(
        cs.primary.withValues(alpha: brightness == Brightness.dark ? 0.05 : 0.03),
        cs.surface,
      ),
      l2Card: Color.alphaBlend(
        cs.primary.withValues(alpha: brightness == Brightness.dark ? 0.09 : 0.06),
        cs.surface,
      ),
      l3Floating: Color.alphaBlend(
        cs.primary.withValues(alpha: brightness == Brightness.dark ? 0.14 : 0.09),
        cs.surface,
      ),
    );
  }

  @override
  SurfaceLadder copyWith({
    Color? l0Canvas,
    Color? l1Elevated,
    Color? l2Card,
    Color? l3Floating,
  }) {
    return SurfaceLadder(
      l0Canvas: l0Canvas ?? this.l0Canvas,
      l1Elevated: l1Elevated ?? this.l1Elevated,
      l2Card: l2Card ?? this.l2Card,
      l3Floating: l3Floating ?? this.l3Floating,
    );
  }

  @override
  SurfaceLadder lerp(ThemeExtension<SurfaceLadder>? other, double t) {
    if (other is! SurfaceLadder) return this;
    return SurfaceLadder(
      l0Canvas: Color.lerp(l0Canvas, other.l0Canvas, t)!,
      l1Elevated: Color.lerp(l1Elevated, other.l1Elevated, t)!,
      l2Card: Color.lerp(l2Card, other.l2Card, t)!,
      l3Floating: Color.lerp(l3Floating, other.l3Floating, t)!,
    );
  }
}

/// Kelivo Semantic Colors (`app_semantic_colors.dart`).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.surfaceFill,
    required this.hairlineBorder,
    required this.chatQuietFill,
  });

  final Color success;
  final Color warning;
  final Color info;
  final Color surfaceFill;
  final Color hairlineBorder;
  final Color chatQuietFill;

  static const _lightSuccess = Color(0xFF1E8E5A);
  static const _darkSuccess = Color(0xFF4ADE80);
  static const _lightWarning = Color(0xFFD97706);
  static const _darkWarning = Color(0xFFFBBF24);
  static const _lightInfo = Color(0xFF2563EB);
  static const _darkInfo = Color(0xFF60A5FA);

  factory AppSemanticColors.fromScheme(
    ColorScheme cs, {
    required Brightness brightness,
    required SurfaceLadder ladder,
  }) {
    final isDark = brightness == Brightness.dark;
    return AppSemanticColors(
      success: isDark ? _darkSuccess : _lightSuccess,
      warning: isDark ? _darkWarning : _lightWarning,
      info: isDark ? _darkInfo : _lightInfo,
      surfaceFill: ladder.l1Elevated,
      hairlineBorder: cs.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.28),
      chatQuietFill: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
    );
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? surfaceFill,
    Color? hairlineBorder,
    Color? chatQuietFill,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      surfaceFill: surfaceFill ?? this.surfaceFill,
      hairlineBorder: hairlineBorder ?? this.hairlineBorder,
      chatQuietFill: chatQuietFill ?? this.chatQuietFill,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      surfaceFill: Color.lerp(surfaceFill, other.surfaceFill, t)!,
      hairlineBorder: Color.lerp(hairlineBorder, other.hairlineBorder, t)!,
      chatQuietFill: Color.lerp(chatQuietFill, other.chatQuietFill, t)!,
    );
  }
}

/// Kelivo Chat Bubble Style (`chat_bubble_style.dart`).
enum ChatBubblePreset { frosted, solid }

@immutable
class ChatBubbleStyleSpec {
  const ChatBubbleStyleSpec({
    this.preset = ChatBubblePreset.frosted,
    this.frostedOpacity = 0.66,
    this.blurSigma = 14.0,
    this.borderWidth = 0.8,
    this.borderOpacity = 0.14,
    this.cornerRadius = 16.0,
  });

  final ChatBubblePreset preset;
  final double frostedOpacity;
  final double blurSigma;
  final double borderWidth;
  final double borderOpacity;
  final double cornerRadius;

  ChatBubbleStyleSpec copyWith({
    ChatBubblePreset? preset,
    double? frostedOpacity,
    double? blurSigma,
    double? borderWidth,
    double? borderOpacity,
    double? cornerRadius,
  }) {
    return ChatBubbleStyleSpec(
      preset: preset ?? this.preset,
      frostedOpacity: frostedOpacity ?? this.frostedOpacity,
      blurSigma: blurSigma ?? this.blurSigma,
      borderWidth: borderWidth ?? this.borderWidth,
      borderOpacity: borderOpacity ?? this.borderOpacity,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }
}

extension KelivoThemeContext on BuildContext {
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
  SurfaceLadder get surfaceLadder =>
      Theme.of(this).extension<SurfaceLadder>()!;
}

/// Authentic Kelivo Theme Palette (`palettes.dart`).
class KelivoPalette {
  final String id;
  final String nameZh;
  final String nameEn;
  final ColorScheme light;
  final ColorScheme dark;
  /// Custom 4 radial blob hues for the Aurora mesh background (`chat_gradient_background.dart`)
  final List<Color> darkAuroraBlobs;
  final List<Color> lightAuroraBlobs;

  const KelivoPalette({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.light,
    required this.dark,
    required this.darkAuroraBlobs,
    required this.lightAuroraBlobs,
  });

  ThemeData toThemeData({required bool isDark}) {
    final cs = isDark ? dark : light;
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final ladder = SurfaceLadder.fromScheme(
      cs,
      brightness: brightness,
      isFrostGray: id == 'frost',
    );
    final semantic = AppSemanticColors.fromScheme(
      cs,
      brightness: brightness,
      ladder: ladder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: <ThemeExtension<dynamic>>[
        ladder,
        semantic,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: cs.onSurface, size: 20),
      ),
      dividerTheme: DividerThemeData(
        color: semantic.hairlineBorder,
        thickness: 0.6,
        space: 1,
      ),
    );
  }
}

/// All 9 authentic Kelivo palettes from `Chevey339/kelivo/lib/theme/palettes.dart`.
class KelivoPalettes {
  static const String defaultId = 'aether';

  static final List<KelivoPalette> all = [
    // 1. 海霄蓝 (Aether Blue)
    KelivoPalette(
      id: 'aether',
      nameZh: '海霄蓝',
      nameEn: 'Aether Blue',
      light: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3E5E98),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF3E5E98),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFD7E2FF),
        onPrimaryContainer: const Color(0xFF001A40),
        secondary: const Color(0xFF565E71),
        secondaryContainer: const Color(0xFFDAE2F9),
        surface: const Color(0xFFFAF9FD),
        onSurface: const Color(0xFF1A1B1F),
      ),
      dark: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3E5E98),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFACC7FF),
        onPrimary: const Color(0xFF062F67),
        primaryContainer: const Color(0xFF24467E),
        onPrimaryContainer: const Color(0xFFD7E2FF),
        secondary: const Color(0xFFBEC6DC),
        secondaryContainer: const Color(0xFF3E4759),
        surface: const Color(0xFF0D1017),
        onSurface: const Color(0xFFE3E2E6),
      ),
      darkAuroraBlobs: const [
        Color(0xFF3E6FB0),
        Color(0xFF2E7D74),
        Color(0xFF4A6E96),
        Color(0xFF7C5F9E),
      ],
      lightAuroraBlobs: const [
        Color(0xFF7EB8E8),
        Color(0xFF8ED5C8),
        Color(0xFF9AC5EB),
        Color(0xFFB8C0E8),
      ],
    ),

    // 2. 默认 (Default Indigo)
    KelivoPalette(
      id: 'default',
      nameZh: '默认靛蓝',
      nameEn: 'Default',
      light: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4D5C92),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF4D5C92),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFDCE1FF),
        onPrimaryContainer: const Color(0xFF03174B),
        surface: const Color(0xFFFAF8FF),
        onSurface: const Color(0xFF1A1B21),
      ),
      dark: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4D5C92),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFB6C4FF),
        onPrimary: const Color(0xFF1D2D61),
        primaryContainer: const Color(0xFF354479),
        onPrimaryContainer: const Color(0xFFDCE1FF),
        surface: const Color(0xFF121318),
        onSurface: const Color(0xFFE3E1E9),
      ),
      darkAuroraBlobs: const [
        Color(0xFF4D5C92),
        Color(0xFF3A6073),
        Color(0xFF5C528A),
        Color(0xFF7C5F9E),
      ],
      lightAuroraBlobs: const [
        Color(0xFF9BB0F8),
        Color(0xFFA0D2EB),
        Color(0xFFB6C4FF),
        Color(0xFFC5B8F0),
      ],
    ),

    // 3. 竹影绿 (Bamboo Green)
    KelivoPalette(
      id: 'bamboo',
      nameZh: '竹影绿',
      nameEn: 'Bamboo Green',
      light: ColorScheme.fromSeed(
        seedColor: const Color(0xFF166C47),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF166C47),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFA3F4C5),
        onPrimaryContainer: const Color(0xFF002112),
        surface: const Color(0xFFF6FBF6),
        onSurface: const Color(0xFF171D19),
      ),
      dark: ColorScheme.fromSeed(
        seedColor: const Color(0xFF166C47),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF87D7AA),
        onPrimary: const Color(0xFF003822),
        primaryContainer: const Color(0xFF005234),
        onPrimaryContainer: const Color(0xFFA3F4C5),
        surface: const Color(0xFF0D1410),
        onSurface: const Color(0xFFDDE4DF),
      ),
      darkAuroraBlobs: const [
        Color(0xFF1E7852),
        Color(0xFF286E6A),
        Color(0xFF3A7B5E),
        Color(0xFF4E6B8A),
      ],
      lightAuroraBlobs: const [
        Color(0xFF82D9B0),
        Color(0xFF8EDBC8),
        Color(0xFFA3F4C5),
        Color(0xFF9ECAE1),
      ],
    ),

    // 4. 暮紫韵 (Twilight Purple)
    KelivoPalette(
      id: 'twilight',
      nameZh: '暮紫韵',
      nameEn: 'Twilight Purple',
      light: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5D5698),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF5D5698),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFE4DFFF),
        onPrimaryContainer: const Color(0xFF19104E),
        surface: const Color(0xFFFCF8FF),
        onSurface: const Color(0xFF1C1B20),
      ),
      dark: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5D5698),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFC8BFFF),
        onPrimary: const Color(0xFF2E2766),
        primaryContainer: const Color(0xFF453E7E),
        onPrimaryContainer: const Color(0xFFE4DFFF),
        surface: const Color(0xFF131218),
        onSurface: const Color(0xFFE5E1E9),
      ),
      darkAuroraBlobs: const [
        Color(0xFF6B5B9E),
        Color(0xFF4A5D96),
        Color(0xFF825692),
        Color(0xFF3E6FB0),
      ],
      lightAuroraBlobs: const [
        Color(0xFFC8BFFF),
        Color(0xFFB5C4F8),
        Color(0xFFDCC2F4),
        Color(0xFFA9C8F5),
      ],
    ),

    // 5. 琥珀金 (Amber Gold)
    KelivoPalette(
      id: 'amber',
      nameZh: '琥珀金',
      nameEn: 'Amber Gold',
      light: ColorScheme.fromSeed(
        seedColor: const Color(0xFF855304),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF855304),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFFFDDB4),
        onPrimaryContainer: const Color(0xFF2A1700),
        surface: const Color(0xFFFFF8F4),
        onSurface: const Color(0xFF201A14),
      ),
      dark: ColorScheme.fromSeed(
        seedColor: const Color(0xFF855304),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFFDB967),
        onPrimary: const Color(0xFF472A00),
        primaryContainer: const Color(0xFF653E00),
        onPrimaryContainer: const Color(0xFFFFDDB4),
        surface: const Color(0xFF16120D),
        onSurface: const Color(0xFFECE0D5),
      ),
      darkAuroraBlobs: const [
        Color(0xFF8C5A14),
        Color(0xFF7A4824),
        Color(0xFF6E5D2C),
        Color(0xFF52607A),
      ],
      lightAuroraBlobs: const [
        Color(0xFFFAD08C),
        Color(0xFFF7BE94),
        Color(0xFFFCE2A6),
        Color(0xFFBDD4EC),
      ],
    ),

    // 6. 暮霭玫 (Smoky Rose)
    KelivoPalette(
      id: 'rose',
      nameZh: '暮霭玫',
      nameEn: 'Smoky Rose',
      light: ColorScheme.fromSeed(
        seedColor: const Color(0xFF824E6C),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF824E6C),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFFFD8EC),
        onPrimaryContainer: const Color(0xFF350C26),
        surface: const Color(0xFFFFF8F9),
        onSurface: const Color(0xFF201A1D),
      ),
      dark: ColorScheme.fromSeed(
        seedColor: const Color(0xFF824E6C),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFF5B3D6),
        onPrimary: const Color(0xFF4E203C),
        primaryContainer: const Color(0xFF673753),
        onPrimaryContainer: const Color(0xFFFFD8EC),
        surface: const Color(0xFF161114),
        onSurface: const Color(0xFFECE0E4),
      ),
      darkAuroraBlobs: const [
        Color(0xFF8C4E72),
        Color(0xFF6B4E84),
        Color(0xFF8E5866),
        Color(0xFF46648C),
      ],
      lightAuroraBlobs: const [
        Color(0xFFF5B3D6),
        Color(0xFFD6BAEB),
        Color(0xFFF8C8D8),
        Color(0xFFB4CBE8),
      ],
    ),

    // 7. 陶砂红 (Terracotta Clay)
    KelivoPalette(
      id: 'terracotta',
      nameZh: '陶砂红',
      nameEn: 'Terracotta Clay',
      light: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B4E3B),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF8B4E3B),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFFFDBD0),
        onPrimaryContainer: const Color(0xFF351004),
        surface: const Color(0xFFFFF8F6),
        onSurface: const Color(0xFF211A18),
      ),
      dark: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B4E3B),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFFFB59E),
        onPrimary: const Color(0xFF522111),
        primaryContainer: const Color(0xFF6E3726),
        onPrimaryContainer: const Color(0xFFFFDBD0),
        surface: const Color(0xFF17110F),
        onSurface: const Color(0xFFEDE0DC),
      ),
      darkAuroraBlobs: const [
        Color(0xFF94523E),
        Color(0xFF825D3A),
        Color(0xFF7D4852),
        Color(0xFF48627C),
      ],
      lightAuroraBlobs: const [
        Color(0xFFFFB59E),
        Color(0xFFF5CCA0),
        Color(0xFFF8B8B8),
        Color(0xFFB6CCE2),
      ],
    ),

    // 8. 纸墨灰 (Frost Gray)
    KelivoPalette(
      id: 'frost',
      nameZh: '纸墨灰',
      nameEn: 'Frost Gray',
      light: const ColorScheme.light(
        primary: Color(0xFF000000),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFE5E7EB),
        onPrimaryContainer: Color(0xFF111827),
        secondary: Color(0xFF4B5563),
        secondaryContainer: Color(0xFFF3F4F6),
        surface: Color(0xFFF7F7F7),
        onSurface: Color(0xFF0F172A),
      ),
      dark: const ColorScheme.dark(
        primary: Color(0xFFFFFFFF),
        onPrimary: Color(0xFF111827),
        primaryContainer: Color(0xFF27272A),
        onPrimaryContainer: Color(0xFFF4F4F5),
        secondary: Color(0xFFA1A1AA),
        secondaryContainer: Color(0xFF27272A),
        surface: Color(0xFF121213),
        onSurface: Color(0xFFF4F4F5),
      ),
      darkAuroraBlobs: const [
        Color(0xFF2A303C),
        Color(0xFF242933),
        Color(0xFF323846),
        Color(0xFF2C3440),
      ],
      lightAuroraBlobs: const [
        Color(0xFFD8DEE9),
        Color(0xFFE5E9F0),
        Color(0xFFCBD5E1),
        Color(0xFFE2E8F0),
      ],
    ),

    // 9. 樱桃绿 (Verdant Mint)
    KelivoPalette(
      id: 'mint',
      nameZh: '樱桃绿',
      nameEn: 'Verdant Mint',
      light: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00B96B),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF00B96B),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFB8F5D4),
        onPrimaryContainer: const Color(0xFF002110),
        surface: const Color(0xFFF7F7F7),
        onSurface: const Color(0xFF181C19),
      ),
      dark: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00B96B),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF00B96B),
        onPrimary: const Color(0xFF002110),
        primaryContainer: const Color(0xFF00522C),
        onPrimaryContainer: const Color(0xFFB8F5D4),
        surface: const Color(0xFF121213),
        onSurface: const Color(0xFFE1E4E2),
      ),
      darkAuroraBlobs: const [
        Color(0xFF0E7C4D),
        Color(0xFF1D6E68),
        Color(0xFF247556),
        Color(0xFF3A607E),
      ],
      lightAuroraBlobs: const [
        Color(0xFF7AE8B8),
        Color(0xFF8EE5D2),
        Color(0xFFA2F2CD),
        Color(0xFFA8D4F0),
      ],
    ),
  ];

  static KelivoPalette byId(String id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => all.first,
    );
  }
}
