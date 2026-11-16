import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Um ponto do trajeto real do motorista (`trip_trail_points`).
class TrailPoint {
  const TrailPoint({
    required this.seq,
    required this.lat,
    required this.lng,
    this.speedKmh,
    required this.recordedAt,
  });

  final int seq;
  final double lat;
  final double lng;
  final double? speedKmh;
  final DateTime recordedAt;

  LatLng get latLng => LatLng(lat, lng);

  static TrailPoint? fromRow(Map<String, dynamic> row) {
    final seq = (row['seq'] as num?)?.toInt();
    final lat = (row['lat'] as num?)?.toDouble();
    final lng = (row['lng'] as num?)?.toDouble();
    if (seq == null || lat == null || lng == null) return null;
    return TrailPoint(
      seq: seq,
      lat: lat,
      lng: lng,
      speedKmh: (row['speed_kmh'] as num?)?.toDouble(),
      recordedAt:
          DateTime.tryParse(row['recorded_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

/// Leitura do traço real de uma viagem no painel admin.
///
/// O admin não escreve: a RLS de `trip_trail_points` só permite SELECT a
/// participantes e a `is_admin()`.
class TripTrailRepository {
  TripTrailRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<TrailPoint>> fetchPoints(String tripId) async {
    try {
      final rows = await _client
          .from('trip_trail_points')
          .select('seq, lat, lng, speed_kmh, recorded_at')
          .eq('trip_id', tripId)
          .order('seq', ascending: true);
      return [
        for (final row in rows)
          if (TrailPoint.fromRow(row) case final point?) point,
      ];
    } catch (e) {
      debugPrint('Admin: erro ao carregar trajeto da viagem: $e');
      return const [];
    }
  }
}
