import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/providers/map_style_provider.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/services/trip_geometry.dart';
import 'package:kupon_office_admin/core/services/trip_route_service.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:kupon_office_admin/repositories/trip_trail_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

/// Traço real de uma viagem, para auditoria no painel admin.
///
/// Mostra o mesmo esquema de cores da app: percorrido a verde, rota planeada a
/// laranja e desvios acima de 80 m a vermelho. O admin só lê.
class AdminTripTrailPage extends StatefulWidget {
  const AdminTripTrailPage({super.key, required this.trip});

  /// Linha de `trips` (inclui `pickup_*`, `destination_*`, `distance`,
  /// `traveled_km`, `duration`, `fare`, `status`, `completed_at`).
  final Map<String, dynamic> trip;

  @override
  State<AdminTripTrailPage> createState() => _AdminTripTrailPageState();
}

class _AdminTripTrailPageState extends State<AdminTripTrailPage> {
  static const Color _trailColor = Color(0xFF4CAF88);
  static const Color _deviationColor = Color(0xFFFF1F48);

  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _loading = true;

  List<LatLng> _route = const [];
  List<LatLng> _trail = const [];
  List<List<LatLng>> _deviationRuns = const [];

  String? get _tripId => widget.trip['id']?.toString();

  LatLng? get _pickup {
    final lat = (widget.trip['pickup_lat'] as num?)?.toDouble();
    final lng = (widget.trip['pickup_lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? get _destination {
    final lat = (widget.trip['destination_lat'] as num?)?.toDouble();
    final lng = (widget.trip['destination_lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String get _status => widget.trip['status']?.toString() ?? 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tripId = _tripId;
    final pickup = _pickup;
    final destination = _destination;

    if (tripId != null) {
      final points = await TripTrailRepository().fetchPoints(tripId);
      if (!mounted) return;
      _trail = [for (final point in points) point.latLng];
    }

    if (pickup != null && destination != null) {
      final route = await TripRouteService.getRoute(
        pickup: pickup,
        destination: destination,
      );
      _route = route;
    }

    _deviationRuns = TripGeometry.deviationRuns(_trail, _route);

    if (!mounted) return;
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToContent());
  }

  void _fitToContent() {
    if (!mounted || !_mapReady) return;
    final points = <LatLng>[
      ..._route,
      ..._trail,
      if (_pickup != null) _pickup!,
      if (_destination != null) _destination!,
    ];
    if (points.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(56, 56, 56, 56),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: KuponLoader(size: 64))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 900;
                          final map = _buildMapCard(height: wide ? 540 : 340);
                          final side = _buildSidePanel();
                          if (!wide) {
                            return Column(
                              children: [map, const SizedBox(height: 16), side],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: map),
                              const SizedBox(width: 20),
                              SizedBox(width: 380, child: side),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: AppTheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: AppTheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trajeto da viagem',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _statusChip(),
        ],
      ),
    );
  }

  String _subtitle() {
    final raw =
        widget.trip['completed_at'] as String? ??
        widget.trip['created_at'] as String?;
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    final id = _tripId;
    final parts = <String>[
      if (date != null) _formatDateTime(date),
      if (id != null) '#${id.substring(0, 8)}',
    ];
    return parts.join('  •  ');
  }

  Widget _statusChip() {
    final (label, color) = switch (_status) {
      'completed' => ('Concluída', _trailColor),
      'cancelled' => ('Cancelada', _deviationColor),
      'in_progress' => ('Em curso', AppTheme.primaryContainer),
      'accepted' || 'arrived' => ('A caminho', AppTheme.tertiary),
      _ => ('Pendente', AppTheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMapCard({required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _pickup ?? const LatLng(-8.8390, 13.2894),
            initialZoom: 14,
            minZoom: 3,
            maxZoom: 18.5,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              _mapReady = true;
              _fitToContent();
            },
          ),
          children: [
            Consumer<MapStyleProvider>(
              builder: (context, mapStyle, _) => mapStyle.buildTileLayer(),
            ),
            PolylineLayer(
              polylines: [
                if (_route.length > 1)
                  Polyline(
                    points: _route,
                    color: AppTheme.primaryContainer.withValues(alpha: 0.45),
                    strokeWidth: 5,
                  ),
                if (_trail.length > 1)
                  Polyline(points: _trail, color: _trailColor, strokeWidth: 6),
                for (final run in _deviationRuns)
                  Polyline(points: run, color: _deviationColor, strokeWidth: 6),
              ],
            ),
            MarkerLayer(
              markers: [
                if (_pickup != null)
                  _marker(
                    _pickup!,
                    icon: Icons.trip_origin_rounded,
                    color: _trailColor,
                  ),
                if (_destination != null)
                  _marker(
                    _destination!,
                    icon: Icons.location_on_rounded,
                    color: AppTheme.primaryContainer,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Marker _marker(LatLng point, {required IconData icon, required Color color}) {
    return Marker(
      point: point,
      width: 34,
      height: 34,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Icon(icon, size: 17, color: Colors.black),
      ),
    );
  }

  Widget _buildSidePanel() {
    final pickupName = widget.trip['pickup_name']?.toString();
    final destinationName = widget.trip['destination_name']?.toString();
    final passenger = _nameOf(widget.trip['passenger']);
    final driver = _driverName();
    final plannedKm = (widget.trip['distance'] as num?)?.toDouble();
    final traveledKm = (widget.trip['traveled_km'] as num?)?.toDouble();
    final duration = (widget.trip['duration'] as num?)?.toInt();
    final fareValue = widget.trip['fare'] ?? widget.trip['estimated_fare'];
    final fare = fareValue is num ? fareValue.toInt() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_trail.length < 2) _buildNoTrailWarning(),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legend(),
              const SizedBox(height: 18),
              if (pickupName != null && pickupName.isNotEmpty)
                _infoRow(Icons.trip_origin_rounded, 'Partida', pickupName),
              if (destinationName != null && destinationName.isNotEmpty)
                _infoRow(Icons.location_on_rounded, 'Destino', destinationName),
              if (passenger != null)
                _infoRow(Icons.person, 'Passageiro', passenger),
              if (driver != null)
                _infoRow(Icons.badge_outlined, 'Motorista', driver),
              const Divider(color: AppTheme.outlineVariant, height: 24),
              _statRow(
                'Distância planeada',
                plannedKm == null ? '—' : '${plannedKm.toStringAsFixed(1)} km',
              ),
              _statRow(
                'Distância percorrida',
                traveledKm == null
                    ? '—'
                    : '${traveledKm.toStringAsFixed(1)} km',
              ),
              _statRow(
                'Duração',
                duration == null || duration <= 0 ? '—' : '$duration min',
              ),
              _statRow('Valor', fare == null ? '—' : 'Kz ${_formatKz(fare)}'),
              _statRow('Pontos do traço', '${_trail.length}'),
              if (_deviationRuns.isNotEmpty)
                _statRow('Troços com desvio', '${_deviationRuns.length}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoTrailWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryContainer.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppTheme.primaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'O trajeto não foi registado para esta viagem. '
              'Apenas a rota planeada está disponível.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        if (_trail.length > 1) _legendItem(_trailColor, 'Percorrido'),
        _legendItem(
          AppTheme.primaryContainer.withValues(alpha: 0.45),
          'Rota planeada',
        ),
        if (_deviationRuns.isNotEmpty)
          _legendItem(_deviationColor, 'Desvio > 80 m'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String? _nameOf(Object? value) {
    if (value is Map) {
      final name = value['name']?.toString();
      if (name != null && name.trim().isNotEmpty) return name;
    }
    return null;
  }

  String? _driverName() {
    final driver = widget.trip['driver'];
    if (driver is! Map) return null;
    return _nameOf(driver['user']) ?? _nameOf(driver);
  }

  String _formatKz(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  String _formatDateTime(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }
}
