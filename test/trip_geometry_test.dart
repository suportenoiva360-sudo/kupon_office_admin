import 'package:flutter_test/flutter_test.dart';
import 'package:kupon_office_admin/core/services/trip_geometry.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // Rota reta ao longo do equador: 0.01° de longitude ≈ 1,11 km.
  const route = [LatLng(0, 0), LatLng(0, 0.01)];

  test('traço sobre a rota não produz desvios', () {
    const trail = [LatLng(0, 0.002), LatLng(0, 0.004), LatLng(0, 0.006)];

    expect(TripGeometry.deviationRuns(trail, route), isEmpty);
  });

  test('desvio acima de 80 m produz um troço com fronteiras', () {
    const trail = [
      LatLng(0, 0.002),
      LatLng(0.002, 0.004), // ~222 m a norte da rota
      LatLng(0, 0.006),
    ];

    final runs = TripGeometry.deviationRuns(trail, route);

    expect(runs, hasLength(1));
    // Inclui os pontos de fronteira para encostar ao percurso verde.
    expect(runs.single, hasLength(3));
    expect(runs.single.first, const LatLng(0, 0.002));
    expect(runs.single.last, const LatLng(0, 0.006));
  });

  test('desvio de 80 m ou menos é ignorado', () {
    const trail = [
      LatLng(0, 0.002),
      LatLng(0.0005, 0.004), // ~55,7 m a norte
      LatLng(0, 0.006),
    ];

    expect(TripGeometry.deviationRuns(trail, route), isEmpty);
  });

  test('traço ou rota com menos de dois pontos devolve vazio', () {
    expect(TripGeometry.deviationRuns(const [], route), isEmpty);
    expect(
      TripGeometry.deviationRuns(const [LatLng(0, 0.002)], route),
      isEmpty,
    );
    expect(
      TripGeometry.deviationRuns(const [
        LatLng(0, 0.002),
        LatLng(0, 0.004),
      ], const []),
      isEmpty,
    );
  });
}
