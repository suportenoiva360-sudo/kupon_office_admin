import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapStyleProvider extends ChangeNotifier {
  String _style = 'escuro';
  bool _loaded = false;

  String get style => _style;

  String get urlTemplate => _styles[_style] ?? _styles['terrestre']!;

  static const String _mapTilerKey = 'QXsz2V7oohxaBkuLbprD';

  static const Map<String, String> _styles = {
    'terrestre': 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    'rua': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'escuro':
        'https://api.maptiler.com/maps/dataviz-dark/{z}/{x}/{y}.png?key=$_mapTilerKey',
    'satelite': 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
    'navegacao':
        'https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=$_mapTilerKey',
  };

  static const Map<String, String> _styleNames = {
    'terrestre': 'Terrestre',
    'rua': 'Rua',
    'escuro': 'Escuro',
    'satelite': 'Satélite',
    'navegacao': 'Navegação',
  };

  static const Map<String, IconData> _styleIcons = {
    'terrestre': Icons.terrain,
    'rua': Icons.map,
    'escuro': Icons.dark_mode,
    'satelite': Icons.satellite_alt,
    'navegacao': Icons.navigation,
  };

  List<String> get availableStyles => _styles.keys.toList();

  String styleName(String key) => _styleNames[key] ?? key;

  IconData styleIcon(String key) => _styleIcons[key] ?? Icons.map;

  Future<void> loadSaved() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pref_map_style_admin');
    if (saved != null && _styles.containsKey(saved)) {
      _style = saved;
      notifyListeners();
    }
    _loaded = true;
  }

  Future<void> setStyle(String style) async {
    if (_styles.containsKey(style)) {
      _style = style;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_map_style_admin', style);
    }
  }
}
