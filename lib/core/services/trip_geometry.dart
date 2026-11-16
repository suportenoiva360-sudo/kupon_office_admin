import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Geometria do trajeto, sem dependências de UI.
///
/// É a mesma lógica usada na app do motorista (`TripTrailService`), mas só a
/// parte necessária ao admin: identificar os troços do traço que estão longe
/// da rota planeada.
class TripGeometry {
  TripGeometry._();

  /// Troços do traço a mais de [thresholdMeters] da rota planeada.
  ///
  /// Cada troço inclui os pontos de fronteira para a linha vermelha encostar
  /// ao percurso verde sem falhas. O traço é decimado a 1 500 pontos e a rota
  /// a [maxRoutePoints] apenas para este cálculo.
  static List<List<LatLng>> deviationRuns(
    List<LatLng> trail,
    List<LatLng> route, {
    double thresholdMeters = 80,
    int maxRoutePoints = 600,
  }) {
    if (trail.length < 2 || route.length < 2) return const [];

    final sampledTrail = trail.length > 1500 ? _decimate(trail, 1500) : trail;

    final origin = route.first;
    final projectedRoute = _decimate(
      route,
      maxRoutePoints,
    ).map((point) => _project(point, origin)).toList(growable: false);

    final offRoute = <bool>[];
    for (final point in sampledTrail) {
      final projected = _project(point, origin);
      offRoute.add(
        _distanceToPolyline(projected, projectedRoute) > thresholdMeters,
      );
    }

    final runs = <List<LatLng>>[];
    int? start;
    for (var i = 0; i < offRoute.length; i++) {
      if (offRoute[i]) {
        start ??= i;
        continue;
      }
      if (start != null) {
        _appendRun(runs, sampledTrail, start - 1, i);
        start = null;
      }
    }
    if (start != null) {
      _appendRun(runs, sampledTrail, start - 1, sampledTrail.length - 1);
    }
    return runs;
  }

  static void _appendRun(
    List<List<LatLng>> runs,
    List<LatLng> trail,
    int start,
    int end,
  ) {
    final from = math.max(0, start);
    final to = math.min(trail.length - 1, end);
    if (to - from < 1) return;
    runs.add(trail.sublist(from, to + 1));
  }

  static List<LatLng> _decimate(List<LatLng> points, int maxPoints) {
    if (points.length <= maxPoints) return points;
    final step = (points.length / maxPoints).ceil();
    final result = <LatLng>[];
    for (var i = 0; i < points.length; i += step) {
      result.add(points[i]);
    }
    if (result.last != points.last) result.add(points.last);
    return result;
  }

  static double _distanceToPolyline(_PlanePoint point, List<_PlanePoint> line) {
    var best = double.infinity;
    for (var i = 0; i < line.length - 1; i++) {
      final distance = _distanceToSegmentSquared(point, line[i], line[i + 1]);
      if (distance < best) best = distance;
    }
    return math.sqrt(best);
  }

  static double _distanceToSegmentSquared(
    _PlanePoint point,
    _PlanePoint a,
    _PlanePoint b,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    if (dx == 0 && dy == 0) {
      final px = point.x - a.x;
      final py = point.y - a.y;
      return px * px + py * py;
    }
    final t =
        (((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy))
            .clamp(0.0, 1.0);
    final px = point.x - (a.x + t * dx);
    final py = point.y - (a.y + t * dy);
    return px * px + py * py;
  }

  /// Projeção equiretangular local (metros): suficiente para percursos
  /// urbanos e muito mais barata do que trigonometria por segmento.
  static _PlanePoint _project(LatLng point, LatLng origin) {
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng =
        metersPerDegreeLat * math.cos(origin.latitude * math.pi / 180.0);
    return _PlanePoint(
      (point.longitude - origin.longitude) * metersPerDegreeLng,
      (point.latitude - origin.latitude) * metersPerDegreeLat,
    );
  }
}

@immutable
class _PlanePoint {
  const _PlanePoint(this.x, this.y);

  final double x;
  final double y;
}
