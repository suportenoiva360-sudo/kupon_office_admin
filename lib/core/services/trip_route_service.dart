import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Rota planeada para o mapa do admin, obtida do OSRM.
///
/// O traço guardado não inclui a rota planeada (só o caminho real), por isso
/// o admin pede-a à mesma API pública usada pela app. Em falha, o chamador
/// usa a linha reta entre partida e destino como aproximação.
class TripRouteService {
  TripRouteService._();

  static const String _osrmUrl =
      'https://router.project-osrm.org/route/v1/driving';
  static const Duration _timeout = Duration(seconds: 4);

  static Future<List<LatLng>> getRoute({
    required LatLng pickup,
    required LatLng destination,
  }) async {
    try {
      final uri = Uri.parse(
        '$_osrmUrl/${pickup.longitude},${pickup.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return const [];

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List?;
      if (coordinates == null) return const [];

      return [
        for (final coordinate in coordinates)
          if (coordinate is List && coordinate.length >= 2)
            LatLng(
              (coordinate[1] as num).toDouble(),
              (coordinate[0] as num).toDouble(),
            ),
      ];
    } catch (e) {
      debugPrint('Admin: OSRM falhou, a usar linha reta: $e');
      return const [];
    }
  }
}
