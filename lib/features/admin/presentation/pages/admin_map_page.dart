import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kupon_office_admin/app/models/province.dart';
import 'package:kupon_office_admin/app/providers/map_style_provider.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:kupon_office_admin/repositories/dashboard_repository.dart';

class AdminMapPage extends StatefulWidget {
  const AdminMapPage({super.key});

  @override
  State<AdminMapPage> createState() => _AdminMapPageState();
}

class _AdminMapPageState extends State<AdminMapPage>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final List<_DriverMarker> _drivers = [];
  RealtimeChannel? _channel;
  Timer? _driverPollTimer;

  final Map<String, String> _provinceIdToCode = {};
  final Map<String, String> _provinceIdToName = {};
  final Map<String, String> _provinceCodeToId = {};

  bool _loading = true;
  _DriverMarker? _selectedDriver;
  String _categoryFilter =
      'all'; // all | car_standard | car_comfort | car_luxury | moto
  String _provinceFilter = 'all'; // all | province codes
  bool _sidePanelOpen = true;

  // Panel collapsed states
  bool _analyticsCollapsed = false;
  bool _demandCollapsed = false;
  bool _eventLogCollapsed = false;

  // Event log data
  final List<_EventLogEntry> _eventLog = [];

  // Live stats from Supabase (no mock data)
  int _ridesToday = 0;
  String _avgWait = '–';
  final List<_DemandZone> _zones = [];
  RealtimeChannel? _tripsChannel;

  // Pulse animation for markers
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  // Smooth camera animation
  late final AnimationController _camAnim;

  static const _luanda = LatLng(-8.8390, 13.2894);

  // ─────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

    _camAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _initData();

    // Fallback polling every 4s to ensure drivers always move & stay synced even if Realtime drops
    _driverPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _loadDrivers(silent: true);
    });
  }

  Future<void> _initData() async {
    await _loadProvincesDb();
    _loadDrivers();
    _loadMapStats();
    _loadInitialEvents();
    _subscribeToAllDrivers();
    _subscribeToTrips();
  }

  Future<void> _loadProvincesDb() async {
    try {
      final res = await Supabase.instance.client
          .from('provinces')
          .select('id, name, code');
      for (final p in (res as List)) {
        final id = p['id'] as String?;
        final name = p['name'] as String?;
        final code = (p['code'] as String?)?.toUpperCase();
        if (id != null) {
          if (code != null && code.isNotEmpty) {
            _provinceIdToCode[id] = code;
            _provinceCodeToId[code] = id;
          }
          if (name != null && name.isNotEmpty) {
            _provinceIdToName[id] = name;
            final kMatch = kProvinces.where(
              (kp) => kp.name.toLowerCase() == name.toLowerCase(),
            );
            if (kMatch.isNotEmpty && (code == null || code.isEmpty)) {
              _provinceIdToCode[id] = kMatch.first.code;
              _provinceCodeToId[kMatch.first.code] = id;
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _driverPollTimer?.cancel();
    _channel?.unsubscribe();
    _tripsChannel?.unsubscribe();
    _pulse.dispose();
    _camAnim.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // Camera animation & Math
  // ─────────────────────────────────────────

  double _calculateBearing(LatLng start, LatLng end) {
    final dLat = (end.latitude - start.latitude).abs();
    final dLng = (end.longitude - start.longitude).abs();
    if (dLat < 0.000005 && dLng < 0.000005) {
      return 0.0;
    }
    final lat1 = start.latitude * (math.pi / 180.0);
    final lon1 = start.longitude * (math.pi / 180.0);
    final lat2 = end.latitude * (math.pi / 180.0);
    final lon2 = end.longitude * (math.pi / 180.0);
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final radians = math.atan2(y, x);
    final degrees = radians * (180.0 / math.pi);
    return (degrees + 360.0) % 360.0;
  }

  /// Animates the map camera smoothly from the current position to [destLatLng]
  /// and [destZoom], using an [Curves.easeInOutCubic] curve.
  void _animateTo(LatLng destLatLng, double destZoom) {
    final startLatLng = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    final latTween = Tween<double>(
      begin: startLatLng.latitude,
      end: destLatLng.latitude,
    );
    final lngTween = Tween<double>(
      begin: startLatLng.longitude,
      end: destLatLng.longitude,
    );
    final zoomTween = Tween<double>(begin: startZoom, end: destZoom);

    final curved = CurvedAnimation(
      parent: _camAnim,
      curve: Curves.easeInOutCubic,
    );

    void listener() {
      if (!mounted) return;
      _mapController.move(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
      );
    }

    _camAnim
      ..reset()
      ..addListener(listener)
      ..forward().whenComplete(() => _camAnim.removeListener(listener));
  }

  // ─────────────────────────────────────────
  // Data
  // ─────────────────────────────────────────

  Future<void> _loadDrivers({bool silent = false}) async {
    try {
      final data = await Supabase.instance.client
          .from('drivers')
          .select(
            'id, user_id, vehicle_model, vehicle_plate, vehicle_color, vehicle_year, rating, current_lat, current_lng, is_online, is_approved, category, total_trips, province_id, users(id, name, phone, email, photo_url), provinces(id, name, code)',
          )
          .eq('is_online', true)
          .eq('is_approved', true)
          .not('current_lat', 'is', null)
          .not('current_lng', 'is', null);

      if (!mounted) return;
      final existingMap = {for (final d in _drivers) d.id: d};
      final List<_DriverMarker> updatedList = [];

      for (final d in (data as List)) {
        final id = d['id'] as String;
        final lat = (d['current_lat'] as num?)?.toDouble();
        final lng = (d['current_lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final newPos = LatLng(lat, lng);
        final prev = existingMap[id];
        double heading = prev?.heading ?? 0.0;

        if (prev != null) {
          final distLat = (newPos.latitude - prev.position.latitude).abs();
          final distLng = (newPos.longitude - prev.position.longitude).abs();
          if (distLat > 0.000015 || distLng > 0.000015) {
            heading = _calculateBearing(prev.position, newPos);
          }
        }

        final userMap = d['users'] as Map<String, dynamic>?;
        final provMap = d['provinces'] as Map<String, dynamic>?;

        final userId = d['user_id'] as String? ?? userMap?['id'] as String?;
        final userName = (userMap?['name'] as String?)?.trim();
        final name = (userName != null && userName.isNotEmpty)
            ? userName
            : ((d['full_name'] as String?)?.trim() ?? 'Motorista');

        final phone = userMap?['phone'] as String?;
        final email = userMap?['email'] as String?;
        final photoUrl = userMap?['photo_url'] as String?;

        final model = (d['vehicle_model'] as String?)?.trim() ?? '';
        final plate = (d['vehicle_plate'] as String?)?.trim() ?? '';
        final year = d['vehicle_year']?.toString();
        final color = d['vehicle_color'] as String?;

        final vehicleStr = model.isNotEmpty && plate.isNotEmpty
            ? '$model · $plate'
            : (model.isNotEmpty
                  ? model
                  : (plate.isNotEmpty ? plate : 'Veículo KupOn'));

        final provId = d['province_id'] as String?;
        var provCode = provMap?['code'] as String? ?? _provinceIdToCode[provId];
        var provName = provMap?['name'] as String? ?? _provinceIdToName[provId];

        if (provCode == null && provName != null) {
          final match = kProvinces.where(
            (p) => p.name.toLowerCase() == provName.toLowerCase(),
          );
          if (match.isNotEmpty) provCode = match.first.code;
        }

        final marker = _DriverMarker(
          id: id,
          userId: userId,
          name: name,
          phone: phone,
          email: email,
          photoUrl: photoUrl,
          vehicle: vehicleStr,
          vehicleModel: model,
          vehiclePlate: plate,
          vehicleYear: year,
          color: color,
          rating: (d['rating'] as num?)?.toDouble() ?? 5.0,
          category: d['category'] as String?,
          provinceId: provId,
          provinceCode: provCode,
          provinceName: provName,
          totalTrips: (d['total_trips'] as int?) ?? 0,
          position: newPos,
          heading: heading,
        );
        updatedList.add(marker);
      }

      setState(() {
        _drivers
          ..clear()
          ..addAll(updatedList);
        if (_selectedDriver != null) {
          final match = _drivers.where((d) => d.id == _selectedDriver!.id);
          _selectedDriver = match.isNotEmpty ? match.first : null;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  /// Loads the event log from real data: recent trips + recent SOS alerts.
  /// If the queries fail (RLS/network), the log stays empty — never mocked.
  Future<void> _loadInitialEvents() async {
    final client = Supabase.instance.client;
    final List<(DateTime, _EventLogEntry)> items = [];

    try {
      final trips = await client
          .from('trips')
          .select(
            'id, status, fare, category, created_at, completed_at, destination_name, driver_id',
          )
          .order('created_at', ascending: false)
          .limit(15);

      final ids = <String>{};
      for (final t in (trips as List)) {
        final driverId = t['driver_id'] as String?;
        if (driverId != null && driverId.isNotEmpty) ids.add(driverId);
      }
      final names = <String, String>{};
      if (ids.isNotEmpty) {
        final ds = await client
            .from('drivers')
            .select('id, full_name')
            .inFilter('id', ids.toList());
        for (final d in (ds as List)) {
          names[d['id'] as String] = (d['full_name'] as String?) ?? 'Motorista';
        }
      }

      for (final t in (trips as List)) {
        final at = DateTime.tryParse(
          '${t['completed_at'] ?? t['created_at'] ?? ''}',
        );
        if (at == null) continue;
        final entry = _tripEntry(
          status: t['status'] as String?,
          category: t['category'] as String?,
          driver: names[t['driver_id'] as String?] ?? 'Motorista',
          fare: t['fare'],
          destination: t['destination_name'] as String?,
          at: at,
        );
        if (entry != null) items.add((at, entry));
      }
    } catch (_) {
      // Keeps the log empty instead of showing mock data.
    }

    try {
      final sos = await client
          .from('sos_alerts')
          .select('address, created_at')
          .order('created_at', ascending: false)
          .limit(3);
      for (final s in (sos as List)) {
        final at = DateTime.tryParse('${s['created_at'] ?? ''}');
        if (at == null) continue;
        items.add((
          at,
          _EventLogEntry(
            time: _hhmm(at),
            title: 'Alerta SOS',
            subtitle: (s['address'] as String?) ?? 'Pedido de ajuda',
            type: _EventType.alert,
          ),
        ));
      }
    } catch (_) {}

    items.sort((a, b) => b.$1.compareTo(a.$1));
    if (!mounted) return;
    setState(() {
      _eventLog
        ..clear()
        ..addAll(items.take(20).map((e) => e.$2));
    });
  }

  /// Builds an event-log entry from a trips row. Null for unknown statuses.
  _EventLogEntry? _tripEntry({
    required String? status,
    required String? category,
    required String driver,
    required Object? fare,
    required String? destination,
    required DateTime at,
  }) {
    final time = _hhmm(at);
    final cat = _categoryLabel(category);
    switch (status) {
      case 'completed':
        final fareNum = fare is num ? fare : num.tryParse('$fare');
        final fareStr = fareNum != null ? 'Kz ${formatNumber(fareNum)}' : null;
        return _EventLogEntry(
          time: time,
          title: 'Corrida Concluída',
          subtitle: '$cat • $driver${fareStr != null ? ' • $fareStr' : ''}',
          type: _EventType.rideCompleted,
        );
      case 'cancelled':
        return _EventLogEntry(
          time: time,
          title: 'Corrida Cancelada',
          subtitle: '$cat • $driver',
          type: _EventType.alert,
        );
      case 'in_progress':
        final dest = (destination ?? '').trim();
        return _EventLogEntry(
          time: time,
          title: 'Corrida em Curso',
          subtitle: '$cat • $driver${dest.isNotEmpty ? ' → $dest' : ''}',
          type: _EventType.rideStarted,
        );
      case 'accepted':
        return _EventLogEntry(
          time: time,
          title: 'Corrida Aceite',
          subtitle: '$cat • $driver',
          type: _EventType.rideStarted,
        );
      case 'pending':
        return _EventLogEntry(
          time: time,
          title: 'Novo Pedido',
          subtitle: cat,
          type: _EventType.rideStarted,
        );
      default:
        return null;
    }
  }

  void _prependEvent(_EventLogEntry entry) {
    _eventLog.insert(0, entry);
    if (_eventLog.length > 20) _eventLog.removeLast();
  }

  String _nowHhmm() {
    final now = TimeOfDay.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _hhmm(DateTime at) {
    final l = at.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  /// Live aggregates for the analytics + demand panels. Each query is
  /// independent so one failure never blanks the others.
  Future<void> _loadMapStats() async {
    final client = Supabase.instance.client;
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().toIso8601String();
    final window48h = now
        .subtract(const Duration(hours: 48))
        .toUtc()
        .toIso8601String();

    var rides = 0;
    var wait = '–';
    final zoneCounts = <String, int>{};

    try {
      final ridesData = await client
          .from('trips')
          .select('id')
          .gte('created_at', todayStart)
          .neq('status', 'cancelled');
      rides = (ridesData as List).length;
    } catch (_) {}

    try {
      final waitData = await client
          .from('trips')
          .select('created_at, started_at')
          .gte('created_at', todayStart)
          .eq('status', 'completed')
          .not('started_at', 'is', null)
          .limit(200);
      var total = 0;
      var n = 0;
      for (final t in (waitData as List)) {
        final created = DateTime.tryParse('${t['created_at'] ?? ''}');
        final started = DateTime.tryParse('${t['started_at'] ?? ''}');
        if (created == null || started == null) continue;
        final diff = started.difference(created).inMinutes;
        if (diff < 0 || diff > 180) continue;
        total += diff;
        n++;
      }
      if (n > 0) wait = '${(total / n).round()}m';
    } catch (_) {}

    try {
      final zoneData = await client
          .from('trips')
          .select('pickup_name')
          .gte('created_at', window48h)
          .order('created_at', ascending: false)
          .limit(300);
      for (final t in (zoneData as List)) {
        final name = (t['pickup_name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        zoneCounts[name] = (zoneCounts[name] ?? 0) + 1;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _ridesToday = rides;
      _avgWait = wait;
      _zones
        ..clear()
        ..addAll(
          (zoneCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(3)
              .map((e) => _DemandZone(name: e.key, requests: e.value)),
        );
    });
  }

  void _subscribeToAllDrivers() {
    _channel = Supabase.instance.client
        .channel('admin-all-drivers-location')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers',
          callback: (payload) {
            if (!mounted) return;
            final rec = payload.newRecord;
            if (rec.isEmpty) return;
            final id = rec['id'] as String?;
            if (id == null) return;

            final lat = (rec['current_lat'] as num?)?.toDouble();
            final lng = (rec['current_lng'] as num?)?.toDouble();
            final isOnline = rec['is_online'] as bool?;
            final isApproved = rec['is_approved'] as bool?;

            final idx = _drivers.indexWhere((d) => d.id == id);

            // If explicitly marked offline or unapproved
            if (isOnline == false || isApproved == false) {
              if (idx != -1) {
                final name = _drivers[idx].name;
                setState(() {
                  _drivers.removeAt(idx);
                  if (_selectedDriver?.id == id) _selectedDriver = null;
                  _prependEvent(
                    _EventLogEntry(
                      time: _nowHhmm(),
                      title: 'Motorista Offline',
                      subtitle: name,
                      type: _EventType.driverOnline,
                    ),
                  );
                });
              }
              return;
            }

            if (lat != null && lng != null) {
              final newPos = LatLng(lat, lng);
              if (idx != -1) {
                final prev = _drivers[idx];
                double heading = prev.heading;
                final distLat = (newPos.latitude - prev.position.latitude)
                    .abs();
                final distLng = (newPos.longitude - prev.position.longitude)
                    .abs();
                if (distLat > 0.000015 || distLng > 0.000015) {
                  heading = _calculateBearing(prev.position, newPos);
                }
                final updated = prev.copyWith(
                  position: newPos,
                  heading: heading,
                  rating: (rec['rating'] as num?)?.toDouble() ?? prev.rating,
                  category: (rec['category'] as String?) ?? prev.category,
                  totalTrips: (rec['total_trips'] as int?) ?? prev.totalTrips,
                );
                setState(() {
                  _drivers[idx] = updated;
                  if (_selectedDriver?.id == id) _selectedDriver = updated;
                });
              } else if (isOnline != false && isApproved != false) {
                final name = (rec['full_name'] as String?) ?? 'Motorista';
                final marker = _DriverMarker(
                  id: id,
                  name: name,
                  vehicle:
                      '${rec['vehicle_model'] ?? ''} · ${rec['vehicle_plate'] ?? ''}',
                  color: rec['vehicle_color'] as String?,
                  rating: (rec['rating'] as num?)?.toDouble() ?? 0,
                  category: rec['category'] as String?,
                  provinceId: rec['province_id'] as String?,
                  totalTrips: (rec['total_trips'] as int?) ?? 0,
                  position: newPos,
                  heading: 0.0,
                );
                setState(() {
                  _drivers.add(marker);
                  _prependEvent(
                    _EventLogEntry(
                      time: _nowHhmm(),
                      title: 'Motorista Online',
                      subtitle:
                          '$name • ${_categoryLabel(rec['category'] as String?)}',
                      type: _EventType.driverOnline,
                    ),
                  );
                });
              }
            }
          },
        )
        .subscribe();
  }

  /// Live trip activity: new requests and status changes update the
  /// event log and refresh the stats.
  void _subscribeToTrips() {
    void onChange(Map<String, dynamic> rec) {
      if (!mounted) return;
      final at =
          DateTime.tryParse(
            '${rec['completed_at'] ?? rec['created_at'] ?? ''}',
          ) ??
          DateTime.now();
      final entry = _tripEntry(
        status: rec['status'] as String?,
        category: rec['category'] as String?,
        driver: 'Motorista',
        fare: rec['fare'],
        destination: rec['destination_name'] as String?,
        at: at,
      );
      setState(() {
        if (entry != null) _prependEvent(entry);
      });
      _loadMapStats();
    }

    _tripsChannel = Supabase.instance.client
        .channel('admin-map-trips')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trips',
          callback: (payload) => onChange(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          callback: (payload) => onChange(payload.newRecord),
        )
        .subscribe();
  }

  // ─────────────────────────────────────────
  // Computed
  // ─────────────────────────────────────────

  List<_DriverMarker> get _filtered {
    var result = _drivers
        .where((d) => d.category == _categoryFilter || _categoryFilter == 'all')
        .toList();

    if (_provinceFilter != 'all') {
      final selectedProv = kProvinces.firstWhere(
        (p) => p.code.toUpperCase() == _provinceFilter.toUpperCase(),
        orElse: () => Province(name: _provinceFilter, code: _provinceFilter),
      );

      final filterCode = _provinceFilter.toUpperCase();
      final filterId = _provinceCodeToId[filterCode] ?? _provinceFilter;
      final filterName = selectedProv.name.toLowerCase();

      result = result.where((d) {
        // Direct matches by code, id, or name
        if (d.provinceCode != null &&
            d.provinceCode!.toUpperCase() == filterCode) {
          return true;
        }
        if (d.provinceId != null &&
            (d.provinceId == filterId || d.provinceId == _provinceFilter)) {
          return true;
        }
        if (d.provinceName != null &&
            d.provinceName!.toLowerCase() == filterName) {
          return true;
        }

        // If driver has no explicit province set in db, match geographically if coordinates are within range of province center
        if (d.provinceId == null && d.provinceCode == null) {
          if (selectedProv.centerLat != null &&
              selectedProv.centerLng != null) {
            final dLat = (d.position.latitude - selectedProv.centerLat!).abs();
            final dLng = (d.position.longitude - selectedProv.centerLng!).abs();
            if (dLat < 1.0 && dLng < 1.0) {
              return true;
            }
          }
        }
        return false;
      }).toList();
    }
    return result;
  }

  int get _standardCount =>
      _drivers.where((d) => d.category == 'car_standard').length;
  int get _comfortCount =>
      _drivers.where((d) => d.category == 'car_comfort').length;
  int get _luxuryCount =>
      _drivers.where((d) => d.category == 'car_luxury').length;
  int get _motoCount => _drivers.where((d) => d.category == 'moto').length;

  // ─────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mapStyle = context.watch<MapStyleProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // ── Full-screen map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _luanda,
              initialZoom: 13,
              onTap: (_, _) => setState(() => _selectedDriver = null),
            ),
            children: [
              TileLayer(
                urlTemplate: mapStyle.urlTemplate,
                userAgentPackageName: 'com.kupon.admin',
                maxZoom: 19,
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // ── Loading indicator ──
          if (_loading)
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KuponLoader(size: 72),
                    const SizedBox(height: 12),
                    Text(
                      'A carregar motoristas...',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Top control bar ──
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildTopBar(mapStyle),
          ),

          // ── Left overlays: Analytics + Demand Zones ──
          Positioned(
            top: 90,
            left: 16,
            bottom: _selectedDriver != null ? 200 : 24,
            child: _buildLeftOverlays(),
          ),

          // ── Right overlays: Vehicle filters + Event Log ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            top: 90,
            right: _sidePanelOpen ? 16 : -380,
            bottom: _selectedDriver != null ? 200 : 24,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              opacity: _sidePanelOpen ? 1.0 : 0.0,
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !_sidePanelOpen,
                child: _buildRightOverlays(),
              ),
            ),
          ),

          // ── Zoom controls (left bottom) ──
          Positioned(
            left: 16,
            bottom: _selectedDriver != null ? 220 : 24,
            child: _buildZoomControls(),
          ),

          // ── Selected driver card (bottom center) ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            bottom: _selectedDriver != null ? 24 : -340,
            left: 0,
            right: 0,
            child: _selectedDriver != null
                ? Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildDriverCard(_selectedDriver!),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Markers
  // ─────────────────────────────────────────

  List<Marker> _buildMarkers() {
    return _filtered.map((d) {
      final isSelected = _selectedDriver?.id == d.id;
      final isMoto = d.category == 'moto';
      final markerSize = isSelected ? 62.0 : (isMoto ? 42.0 : 46.0);
      final assetSize = isSelected ? 44.0 : (isMoto ? 28.0 : 32.0);
      final color = _markerColor(d.category);

      return Marker(
        point: d.position,
        width: markerSize,
        height: markerSize,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedDriver = isSelected ? null : d);
            if (!isSelected) {
              _mapController.move(d.position, _mapController.camera.zoom);
            }
          },
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse halo ring when selected
                  if (isSelected)
                    Container(
                      width: markerSize * (0.85 + _pulseAnim.value * 0.3),
                      height: markerSize * (0.85 + _pulseAnim.value * 0.3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(
                          alpha: (1 - _pulseAnim.value) * 0.4,
                        ),
                      ),
                    ),
                  // Ambient backing glow / shadow disc
                  Container(
                    width: isSelected ? 48.0 : (isMoto ? 34.0 : 36.0),
                    height: isSelected ? 48.0 : (isMoto ? 34.0 : 36.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF14171A).withValues(alpha: 0.85),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : color.withValues(alpha: 0.75),
                        width: isSelected ? 2.0 : 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(
                            alpha: isSelected ? 0.75 : 0.4,
                          ),
                          blurRadius: isSelected ? 16 : 8,
                          spreadRadius: isSelected ? 2 : 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  // Rotated topdown vehicle image asset
                  Transform.rotate(
                    angle: d.heading * (math.pi / 180.0),
                    child: SizedBox(
                      width: assetSize,
                      height: assetSize,
                      child: Image.asset(
                        _categoryMarkerAsset(d.category),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              _categoryIcon(d.category),
                              color: Colors.white,
                              size: isSelected ? 22 : 16,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Online green pulse dot
                  Positioned(
                    top: isSelected ? 6 : 4,
                    right: isSelected ? 6 : 4,
                    child: Container(
                      width: isSelected ? 8 : 7,
                      height: isSelected ? 8 : 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00E676),
                        border: Border.all(color: Colors.black, width: 1.2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }).toList();
  }

  // ─────────────────────────────────────────
  // Top Bar
  // ─────────────────────────────────────────

  Widget _buildTopBar(MapStyleProvider mapStyle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Back button
            _topBarButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),

            // Title
            Icon(Icons.map_rounded, color: AppTheme.primaryContainer, size: 17),
            const SizedBox(width: 8),
            Text(
              'MAPA AO VIVO',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 16),

            // Live badge
            _buildLiveBadge(),

            const Spacer(),

            // Category filters
            _buildCategoryFilters(),
            const SizedBox(width: 12),
            // Province filters
            _buildProvinceFilters(),

            const SizedBox(width: 12),

            // Map style selector
            _buildStyleSelector(mapStyle),
            const SizedBox(width: 8),

            // Side panel toggle
            _topBarButton(
              icon: _sidePanelOpen
                  ? Icons.last_page_rounded
                  : Icons.first_page_rounded,
              onTap: () => setState(() => _sidePanelOpen = !_sidePanelOpen),
              active: _sidePanelOpen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBarButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryContainer.withValues(alpha: 0.15)
              : AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppTheme.primaryContainer.withValues(alpha: 0.4)
                : AppTheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: active
              ? AppTheme.primaryContainer
              : AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  /// Reusable animated chevron button for collapsing/expanding panels.
  Widget _collapseButton({
    required bool collapsed,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedRotation(
        turns: collapsed ? -0.25 : 0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4CAF50),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF4CAF50,
                    ).withValues(alpha: _pulseAnim.value * 0.9),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'AO VIVO · ${_filtered.length}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4CAF50),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final filters = [
      ('all', 'Todos', null),
      ('car_standard', 'Standard', AppTheme.primaryContainer),
      ('car_comfort', 'Comfort', const Color(0xFF2196F3)),
      ('car_luxury', 'Luxury', const Color(0xFFFFD700)),
      ('moto', 'Moto', const Color(0xFF4CAF50)),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: filters.map((f) {
          final isActive = _categoryFilter == f.$1;
          final color = f.$3 ?? AppTheme.onSurfaceVariant;
          return GestureDetector(
            onTap: () => setState(() => _categoryFilter = f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: isActive
                    ? Border.all(color: color.withValues(alpha: 0.5))
                    : null,
              ),
              child: Text(
                f.$2,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? color
                      : AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Province Filters
  // ─────────────────────────────────────────
  Widget _buildProvinceFilters() {
    final List<(String, String)> filters = [
      ('all', 'Todas as Províncias'),
      ...kProvinces.map((p) => (p.code, p.name)),
    ];

    final activeLabel = _provinceFilter == 'all'
        ? 'Províncias'
        : kProvinces
              .firstWhere(
                (p) => p.code == _provinceFilter,
                orElse: () => const Province(name: 'Províncias', code: 'all'),
              )
              .name;

    return PopupMenuButton<String>(
      tooltip: 'Filtrar por província',
      onSelected: (v) {
        setState(() => _provinceFilter = v);
        if (v == 'all') {
          _animateTo(_luanda, 13);
        } else {
          final province = kProvinces.firstWhere(
            (p) => p.code == v,
            orElse: () => const Province(name: '', code: ''),
          );
          if (province.centerLat != null && province.centerLng != null) {
            _animateTo(
              LatLng(province.centerLat!, province.centerLng!),
              province.zoom,
            );
          }
        }
      },
      color: AppTheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      itemBuilder: (_) => filters.map((f) {
        final isActive = _provinceFilter == f.$1;
        return PopupMenuItem<String>(
          value: f.$1,
          child: Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: isActive
                    ? AppTheme.primaryContainer
                    : AppTheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                f.$2,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: isActive
                      ? AppTheme.primaryContainer
                      : AppTheme.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              if (isActive) ...[
                const Spacer(),
                Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: AppTheme.primaryContainer,
                ),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _provinceFilter != 'all'
              ? AppTheme.primaryContainer.withValues(alpha: 0.12)
              : AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _provinceFilter != 'all'
                ? AppTheme.primaryContainer.withValues(alpha: 0.4)
                : AppTheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 14,
              color: _provinceFilter != 'all'
                  ? AppTheme.primaryContainer
                  : AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 5),
            Text(
              activeLabel,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _provinceFilter != 'all'
                    ? AppTheme.primaryContainer
                    : AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleSelector(MapStyleProvider mapStyle) {
    return PopupMenuButton<String>(
      tooltip: 'Estilo do mapa',
      onSelected: (v) => mapStyle.setStyle(v),
      color: AppTheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      itemBuilder: (_) => mapStyle.availableStyles.map((s) {
        final isActive = s == mapStyle.style;
        return PopupMenuItem(
          value: s,
          child: Row(
            children: [
              Icon(
                mapStyle.styleIcon(s),
                size: 15,
                color: isActive
                    ? AppTheme.primaryContainer
                    : AppTheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                mapStyle.styleName(s),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: isActive
                      ? AppTheme.primaryContainer
                      : AppTheme.onSurfaceVariant,
                ),
              ),
              if (isActive) ...[
                const Spacer(),
                Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: AppTheme.primaryContainer,
                ),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mapStyle.styleIcon(mapStyle.style),
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
              size: 15,
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.expand_more_rounded,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Left Overlays: Analytics + Demand Zones
  // ─────────────────────────────────────────

  Widget _buildLeftOverlays() {
    return SizedBox(
      width: 300,
      child: Column(
        children: [
          // Live Analytics Panel
          _buildLiveAnalyticsPanel(),
          const SizedBox(height: 12),
          // High Demand Zones Panel
          _buildDemandZonesPanel(),
        ],
      ),
    );
  }

  Widget _buildLiveAnalyticsPanel() {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: AppTheme.primaryContainer,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LIVE ANALYTICS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _collapseButton(
                collapsed: _analyticsCollapsed,
                onTap: () =>
                    setState(() => _analyticsCollapsed = !_analyticsCollapsed),
              ),
            ],
          ),

          // Collapsible body
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _analyticsCollapsed
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildStatRow(
                        label: 'Motoristas Ativos',
                        value: '${_drivers.length}',
                        valueColor: AppTheme.primaryContainer,
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow(
                        label: 'Corridas Hoje',
                        value: formatNumber(_ridesToday),
                        valueColor: AppTheme.onSurface,
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow(
                        label: 'Tempo Médio Espera',
                        value: _avgWait,
                        valueColor: AppTheme.onSurface,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _statPill(
                            'Standard',
                            _standardCount,
                            AppTheme.primaryContainer,
                          ),
                          _statPill(
                            'Comfort',
                            _comfortCount,
                            const Color(0xFF2196F3),
                          ),
                          _statPill(
                            'Luxury',
                            _luxuryCount,
                            const Color(0xFFFFD700),
                          ),
                          _statPill(
                            'Moto',
                            _motoCount,
                            const Color(0xFF4CAF50),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandZonesPanel() {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: const Color(0xFFCF6679),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ZONAS DE ALTA DEMANDA',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _collapseButton(
                collapsed: _demandCollapsed,
                onTap: () =>
                    setState(() => _demandCollapsed = !_demandCollapsed),
              ),
            ],
          ),

          // Collapsible body
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _demandCollapsed
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      if (_zones.isEmpty)
                        Text(
                          'Sem pedidos recentes',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < _zones.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _buildZoneItem(
                            name: _zones[i].name,
                            badge: '${_zones[i].requests} pedidos',
                            badgeColor: i == 0
                                ? AppTheme.errorContainer
                                : i == 1
                                ? AppTheme.primaryContainer.withValues(
                                    alpha: 0.2,
                                  )
                                : AppTheme.surfaceContainerHighest,
                            badgeTextColor: i == 0
                                ? AppTheme.onErrorContainer
                                : i == 1
                                ? AppTheme.primaryContainer
                                : AppTheme.onSurfaceVariant,
                          ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneItem({
    required String name,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeTextColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Right Overlays: Vehicle Filters + Event Log
  // ─────────────────────────────────────────

  Widget _buildRightOverlays() {
    return SizedBox(
      width: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Vehicle filter bar
          _buildVehicleFilters(),
          const SizedBox(height: 12),
          // Event log
          Expanded(child: _buildEventLogPanel()),
        ],
      ),
    );
  }

  Widget _buildVehicleFilters() {
    final filters = [
      ('all', 'Todos'),
      ('car_standard', 'Standard'),
      ('car_comfort', 'Comfort'),
      ('car_luxury', 'Luxury'),
    ];

    return GlassPanel(
      padding: const EdgeInsets.all(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: filters.map((f) {
          final isActive = _categoryFilter == f.$1;
          return GestureDetector(
            onTap: () => setState(() => _categoryFilter = f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.surfaceContainerHigh
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isActive
                    ? Border.all(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.3),
                      )
                    : null,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryContainer.withValues(
                            alpha: 0.1,
                          ),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                f.$2,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? AppTheme.primaryContainer
                      : AppTheme.onSurface,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventLogPanel() {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.list_alt_rounded,
                color: AppTheme.onSurfaceVariant,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LOG DE EVENTOS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, _) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryContainer.withValues(
                          alpha: _pulseAnim.value * 0.8,
                        ),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              _collapseButton(
                collapsed: _eventLogCollapsed,
                onTap: () =>
                    setState(() => _eventLogCollapsed = !_eventLogCollapsed),
              ),
            ],
          ),

          // Collapsible body — uses Expanded only when visible
          if (!_eventLogCollapsed) ...[
            const SizedBox(height: 14),
            Expanded(
              child: _eventLog.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum evento registado',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _eventLog.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final event = _eventLog[i];
                        return _buildEventLogItem(event);
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventLogItem(_EventLogEntry event) {
    Color borderColor;
    switch (event.type) {
      case _EventType.rideStarted:
      case _EventType.rideCompleted:
        borderColor = AppTheme.primaryContainer;
        break;
      case _EventType.driverOnline:
        borderColor = AppTheme.surfaceContainerHighest;
        break;
      case _EventType.alert:
        borderColor = const Color(0xFFCF6679);
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time
        Container(
          width: 40,
          margin: const EdgeInsets.only(top: 2),
          child: Text(
            event.time,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        // Border indicator
        Container(
          width: 2,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: borderColor,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: event.type == _EventType.alert
                      ? const Color(0xFFCF6679)
                      : AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                event.subtitle,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Zoom Controls
  // ─────────────────────────────────────────

  Widget _buildZoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _zoomButton(
            icon: Icons.add_rounded,
            onTap: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom + 1,
            ),
            isTop: true,
          ),
          Divider(
            height: 1,
            color: AppTheme.outlineVariant.withValues(alpha: 0.2),
          ),
          _zoomButton(
            icon: Icons.remove_rounded,
            onTap: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom - 1,
            ),
          ),
          Divider(
            height: 1,
            color: AppTheme.outlineVariant.withValues(alpha: 0.2),
          ),
          _zoomButton(
            icon: Icons.my_location_rounded,
            onTap: () => _mapController.move(_luanda, 13),
            isBottom: true,
            iconColor: AppTheme.primaryContainer,
          ),
        ],
      ),
    );
  }

  Widget _zoomButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isTop = false,
    bool isBottom = false,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: isTop ? const Radius.circular(14) : Radius.zero,
            bottom: isBottom ? const Radius.circular(14) : Radius.zero,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: iconColor ?? AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Selected Driver Card
  // ─────────────────────────────────────────

  Widget _buildDriverCard(_DriverMarker driver) {
    final color = _markerColor(driver.category);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              // Avatar with category color ring / photo
              Container(
                width: 52,
                height: 52,
                padding: driver.photoUrl != null
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: ClipOval(
                  child: driver.photoUrl != null && driver.photoUrl!.isNotEmpty
                      ? Image.network(
                          driver.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                _categoryMarkerAsset(driver.category),
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, stack) => Icon(
                                  _categoryIcon(driver.category),
                                  color: color,
                                  size: 24,
                                ),
                              ),
                        )
                      : Image.asset(
                          _categoryMarkerAsset(driver.category),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            _categoryIcon(driver.category),
                            color: color,
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car_filled_rounded,
                          size: 13,
                          color: AppTheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            driver.vehicle,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.onSurfaceVariant.withValues(
                                alpha: 0.75,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (driver.phone != null && driver.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 12,
                            color: const Color(0xFF00E676),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            driver.phone!,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: const Color(0xFF00E676),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Rating badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AppTheme.primaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      driver.rating.toStringAsFixed(1),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Info row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _infoChip(
                  icon: _categoryIcon(driver.category),
                  label: _categoryLabel(driver.category),
                  color: color,
                ),
                if (driver.provinceName != null &&
                    driver.provinceName!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _infoChip(
                    icon: Icons.location_city_rounded,
                    label: driver.provinceName!,
                    color: const Color(0xFF29B6F6),
                  ),
                ],
                const SizedBox(width: 8),
                _infoChip(
                  icon: Icons.route_rounded,
                  label: '${driver.totalTrips} corridas',
                  color: AppTheme.tertiary,
                ),
                const SizedBox(width: 8),
                _infoChip(
                  icon: Icons.gps_fixed_rounded,
                  label:
                      '${driver.position.latitude.toStringAsFixed(3)}, ${driver.position.longitude.toStringAsFixed(3)}',
                  color: const Color(0xFF4CAF50),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.person_search_rounded,
                  label: 'Ver Perfil',
                  onTap: () => context.push('/motorista/${driver.id}'),
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 10),
              _actionButton(
                icon: Icons.close_rounded,
                label: 'Fechar',
                onTap: () => setState(() => _selectedDriver = null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isPrimary ? 0 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppTheme.primaryGradient : null,
          color: isPrimary
              ? null
              : AppTheme.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.3),
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppTheme.primaryContainer.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: isPrimary
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: Colors.black),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              )
            : Icon(
                icon,
                size: 16,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────

  String _categoryMarkerAsset(String? category) {
    switch (category) {
      case 'moto':
        return 'assets/images/moto_topdown.png';
      case 'car_luxury':
        return 'assets/images/car_luxury.png';
      case 'car_comfort':
        return 'assets/images/car_confort.png';
      case 'car_standard':
      default:
        return 'assets/images/car_topdown_3d.png';
    }
  }

  Color _markerColor(String? category) {
    switch (category) {
      case 'car_comfort':
        return const Color(0xFF2196F3);
      case 'car_luxury':
        return const Color(0xFFFFD700);
      case 'car_standard':
        return AppTheme.primaryContainer;
      case 'moto':
        return const Color(0xFF4CAF50);
      default:
        return AppTheme.primaryContainer;
    }
  }

  IconData _categoryIcon(String? cat) {
    switch (cat) {
      case 'moto':
        return Icons.two_wheeler_rounded;
      case 'car_luxury':
      case 'car_comfort':
      case 'car_standard':
      default:
        return Icons.directions_car_rounded;
    }
  }

  String _categoryLabel(String? cat) {
    switch (cat) {
      case 'car_comfort':
        return 'Comfort';
      case 'car_luxury':
        return 'Luxury';
      case 'car_standard':
        return 'Standard';
      case 'moto':
        return 'Moto';
      default:
        return cat ?? '—';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Panel Widget
// ─────────────────────────────────────────────────────────────────────────────

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

enum _EventType { rideStarted, driverOnline, rideCompleted, alert }

/// Top pickup location aggregated from real trip requests.
class _DemandZone {
  final String name;
  final int requests;

  const _DemandZone({required this.name, required this.requests});
}

class _EventLogEntry {
  final String time;
  final String title;
  final String subtitle;
  final _EventType type;

  const _EventLogEntry({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.type,
  });
}

class _DriverMarker {
  final String id;
  final String? userId;
  final String name;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String vehicle;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? vehicleYear;
  final String? color;
  final double rating;
  final String? category;
  final String? provinceId;
  final String? provinceCode;
  final String? provinceName;
  final int totalTrips;
  final LatLng position;
  final double heading;

  const _DriverMarker({
    required this.id,
    this.userId,
    required this.name,
    this.phone,
    this.email,
    this.photoUrl,
    required this.vehicle,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleYear,
    this.color,
    required this.rating,
    this.category,
    this.provinceId,
    this.provinceCode,
    this.provinceName,
    required this.totalTrips,
    required this.position,
    this.heading = 0.0,
  });

  _DriverMarker copyWith({
    LatLng? position,
    double? heading,
    String? name,
    String? userId,
    String? phone,
    String? email,
    String? photoUrl,
    String? vehicle,
    String? vehicleModel,
    String? vehiclePlate,
    String? vehicleYear,
    String? color,
    double? rating,
    String? category,
    String? provinceId,
    String? provinceCode,
    String? provinceName,
    int? totalTrips,
  }) => _DriverMarker(
    id: id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    photoUrl: photoUrl ?? this.photoUrl,
    vehicle: vehicle ?? this.vehicle,
    vehicleModel: vehicleModel ?? this.vehicleModel,
    vehiclePlate: vehiclePlate ?? this.vehiclePlate,
    vehicleYear: vehicleYear ?? this.vehicleYear,
    color: color ?? this.color,
    rating: rating ?? this.rating,
    category: category ?? this.category,
    provinceId: provinceId ?? this.provinceId,
    provinceCode: provinceCode ?? this.provinceCode,
    provinceName: provinceName ?? this.provinceName,
    totalTrips: totalTrips ?? this.totalTrips,
    position: position ?? this.position,
    heading: heading ?? this.heading,
  );
}
