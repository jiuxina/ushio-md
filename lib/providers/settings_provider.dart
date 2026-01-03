import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for app settings and theme
class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 16.0;
  bool _autoSave = true;
  int _autoSaveInterval = 30; // seconds
  String? _defaultDirectory;
  
  // Theme color settings
  int _primaryColorIndex = 0; // Index in predefined colors
  
  // Background settings
  String? _backgroundImagePath;
  String _backgroundEffect = 'none'; // none, blur, overlay
  double _backgroundBlur = 10.0;
  double _backgroundOverlayOpacity = 0.5;

  // Predefined theme colors
  static const List<Color> themeColors = [
    Color(0xFF6366F1), // Indigo (default)
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
  ];

  // Getters
  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  bool get autoSave => _autoSave;
  int get autoSaveInterval => _autoSaveInterval;
  String? get defaultDirectory => _defaultDirectory;
  int get primaryColorIndex => _primaryColorIndex;
  Color get primaryColor => themeColors[_primaryColorIndex];
  String? get backgroundImagePath => _backgroundImagePath;
  String get backgroundEffect => _backgroundEffect;
  double get backgroundBlur => _backgroundBlur;
  double get backgroundOverlayOpacity => _backgroundOverlayOpacity;

  /// Initialize settings from storage
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];

    _fontSize = prefs.getDouble('font_size') ?? 16.0;
    _autoSave = prefs.getBool('auto_save') ?? true;
    _autoSaveInterval = prefs.getInt('auto_save_interval') ?? 30;
    _defaultDirectory = prefs.getString('default_directory');
    
    _primaryColorIndex = prefs.getInt('primary_color_index') ?? 0;
    _backgroundImagePath = prefs.getString('background_image_path');
    _backgroundEffect = prefs.getString('background_effect') ?? 'none';
    _backgroundBlur = prefs.getDouble('background_blur') ?? 10.0;
    _backgroundOverlayOpacity = prefs.getDouble('background_overlay_opacity') ?? 0.5;

    notifyListeners();
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  /// Set primary color
  Future<void> setPrimaryColorIndex(int index) async {
    _primaryColorIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primary_color_index', index);
    notifyListeners();
  }

  /// Set background image
  Future<void> setBackgroundImage(String? path) async {
    _backgroundImagePath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('background_image_path', path);
    } else {
      await prefs.remove('background_image_path');
    }
    notifyListeners();
  }

  /// Set background effect
  Future<void> setBackgroundEffect(String effect) async {
    _backgroundEffect = effect;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('background_effect', effect);
    notifyListeners();
  }

  /// Set background blur
  Future<void> setBackgroundBlur(double blur) async {
    _backgroundBlur = blur;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_blur', blur);
    notifyListeners();
  }

  /// Set background overlay opacity
  Future<void> setBackgroundOverlayOpacity(double opacity) async {
    _backgroundOverlayOpacity = opacity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_overlay_opacity', opacity);
    notifyListeners();
  }

  /// Set font size
  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
    notifyListeners();
  }

  /// Set auto save
  Future<void> setAutoSave(bool value) async {
    _autoSave = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_save', value);
    notifyListeners();
  }

  /// Set auto save interval
  Future<void> setAutoSaveInterval(int seconds) async {
    _autoSaveInterval = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_save_interval', seconds);
    notifyListeners();
  }

  /// Set default directory
  Future<void> setDefaultDirectory(String? path) async {
    _defaultDirectory = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('default_directory', path);
    } else {
      await prefs.remove('default_directory');
    }
    notifyListeners();
  }
}
