import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

/// Rota planeada para o mapa do admin, obtida do OSRM.
///
/// O traço guardado não inclui a rota planeada (só o caminho real), por isso
/// o admin pede-a à mesma API pública usada pela app. Em falha, devolve vazio;
/// nunca cria uma linha recta que possa ser confundida com rota rodoviária.
class TripRouteService {
  TripRouteService._();

  static const Duration _timeout = Duration(seconds: 7);

  static Future<List<LatLng>> getRoute({
    required LatLng pickup,
    required LatLng destination,
  }) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke(
            'osrm-route',
            body: {
              'origin': {'lat': pickup.latitude, 'lng': pickup.longitude},
              'destination': {
                'lat': destination.latitude,
                'lng': destination.longitude,
              },
              'waypoints': <Map<String, double>>[],
            },
          )
          .timeout(_timeout);
      if (response.data is! Map) return const [];
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['status'] != 'valid' || data['provider'] != 'osrm') {
        return const [];
      }
      final route = data['route'];
      if (route is! Map) return const [];
      final geometry = route['geometry'];
      if (geometry is! Map || geometry['coordinates'] is! List) {
        return const [];
      }
      final coordinates = geometry['coordinates'] as List;
      final distance = data['distance_meters'];
      final duration = data['duration_seconds'];
      if (distance is! num ||
          distance <= 0 ||
          duration is! num ||
          duration <= 0 ||
          coordinates.length < 2) {
        return const [];
      }
      final points = <LatLng>[];
      for (final coordinate in coordinates) {
        if (coordinate is! List ||
            coordinate.length < 2 ||
            coordinate[0] is! num ||
            coordinate[1] is! num) {
          return const [];
        }
        points.add(
          LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          ),
        );
      }
      return points;
    } catch (e) {
      debugPrint('Admin: não foi possível obter rota rodoviária central: $e');
      return const [];
    }
  }
}
