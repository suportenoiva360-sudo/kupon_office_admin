import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_trip_trail_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Página **Viagens**: pesquisa global das últimas viagens para auditoria.
///
/// Complementa o separador Viagens do detalhe do motorista (que só mostra as
/// viagens de um motorista). Cada cartão abre o traço real da viagem.
class AdminTripsPage extends StatefulWidget {
  const AdminTripsPage({super.key});

  @override
  State<AdminTripsPage> createState() => _AdminTripsPageState();
}

class _AdminTripsPageState extends State<AdminTripsPage> {
  static const int _limit = 200;

  final _db = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _loadFailed = false;
  String _filter = 'all';
  List<Map<String, dynamic>> _trips = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final rows = await _db
          .from('trips')
          .select(
            'id, status, category, created_at, completed_at, '
            'pickup_name, destination_name, pickup_lat, pickup_lng, '
            'destination_lat, destination_lng, distance, traveled_km, '
            'duration, fare, estimated_fare, '
            'passenger:users!trips_passenger_id_fkey(name), '
            'driver:drivers!trips_driver_id_fkey(user:users(name))',
          )
          .order('created_at', ascending: false)
          .limit(_limit);
      if (!mounted) return;
      setState(() {
        _trips = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _trips.where((trip) {
      final status = trip['status']?.toString() ?? 'pending';
      if (_filter != 'all' && status != _filter) return false;
      if (query.isEmpty) return true;
      final haystack = [
        trip['id'],
        trip['pickup_name'],
        trip['destination_name'],
        _nameOf(trip['passenger']),
        _driverName(trip),
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: _loading
          ? const Center(child: KuponLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBar(),
                  const SizedBox(height: 20),
                  _buildSearchRow(),
                  const SizedBox(height: 12),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  if (_loadFailed)
                    _buildMessage(
                      icon: Icons.wifi_off_rounded,
                      text: 'Não foi possível carregar as viagens.',
                      action: _load,
                    )
                  else if (_trips.isEmpty)
                    _buildMessage(
                      icon: Icons.directions_car_outlined,
                      text: 'Nenhuma viagem registada.',
                      action: _load,
                    )
                  else if (_filtered.isEmpty)
                    _buildMessage(
                      icon: Icons.search_off_rounded,
                      text: 'Nada corresponde à pesquisa.',
                      action: () {
                        _searchCtrl.clear();
                        setState(() => _filter = 'all');
                      },
                    )
                  else
                    ..._filtered.map(_buildTripCard),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderBar() {
    final total = _trips.length;
    final withTrail = _trips
        .where((t) => t['pickup_lat'] != null && t['destination_lat'] != null)
        .length;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.route_rounded,
            color: AppTheme.primaryContainer,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Viagens',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Últimas $total viagens · $withTrail com coordenadas para o traço',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Atualizar',
          icon: const Icon(Icons.refresh_rounded),
          color: AppTheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _buildSearchRow() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.spaceGrotesk(fontSize: 13, color: AppTheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Pesquisar por id, rota, passageiro ou motorista',
        hintStyle: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppTheme.onSurfaceVariant,
        ),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                onPressed: () => setState(_searchCtrl.clear),
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppTheme.onSurfaceVariant,
              ),
        filled: true,
        fillColor: AppTheme.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryContainer),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    const filters = [
      ('all', 'Todas'),
      ('completed', 'Concluídas'),
      ('cancelled', 'Canceladas'),
      ('in_progress', 'Em curso'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in filters)
          GestureDetector(
            onTap: () => setState(() => _filter = value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _filter == value
                    ? AppTheme.primaryContainer.withValues(alpha: 0.18)
                    : AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: _filter == value
                      ? AppTheme.primaryContainer
                      : AppTheme.outlineVariant,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _filter == value
                      ? AppTheme.primaryContainer
                      : AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final status = trip['status']?.toString() ?? 'pending';
    final statusColor = _statusColor(status);
    final id = trip['id']?.toString() ?? '';
    final pickup = trip['pickup_name']?.toString() ?? '–';
    final destination = trip['destination_name']?.toString() ?? '–';
    final passenger = _nameOf(trip['passenger']);
    final driver = _driverName(trip);
    final fareValue = trip['fare'] ?? trip['estimated_fare'];
    final fare = fareValue is num ? fareValue.toInt() : null;
    final traveled = (trip['traveled_km'] as num?)?.toDouble();
    final hasCoordinates =
        trip['pickup_lat'] != null && trip['destination_lat'] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openTrail(trip),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasCoordinates
                        ? Icons.route_rounded
                        : Icons.directions_car_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            id.length >= 8 ? '#${id.substring(0, 8)}' : '#$id',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _chip(_statusLabel(status), statusColor),
                          if (!hasCoordinates) ...[
                            const SizedBox(width: 6),
                            _chip('Sem coordenadas', AppTheme.onSurfaceVariant),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$pickup → $destination',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (passenger != null) 'Passageiro: $passenger',
                          if (driver != null) 'Motorista: $driver',
                        ].join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          color: AppTheme.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmtDate(trip['created_at']),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (traveled != null)
                      Text(
                        '${traveled.toStringAsFixed(1)} km',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          color: AppTheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    if (fare != null)
                      Text(
                        'Kz ${_formatKz(fare)}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryContainer,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTrail(Map<String, dynamic> trip) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AdminTripTrailPage(trip: trip)),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String text,
    required VoidCallback action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppTheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: action, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF4CAF88);
      case 'cancelled':
        return const Color(0xFFFF1F48);
      case 'in_progress':
        return AppTheme.primaryContainer;
      case 'accepted' || 'arrived':
        return AppTheme.tertiary;
      default:
        return const Color(0xFFF5C842);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Concluída';
      case 'cancelled':
        return 'Cancelada';
      case 'in_progress':
        return 'Em curso';
      case 'accepted':
        return 'Aceita';
      case 'arrived':
        return 'No embarque';
      default:
        return 'Pendente';
    }
  }

  String? _nameOf(Object? value) {
    if (value is Map) {
      final name = value['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  String? _driverName(Map<String, dynamic> trip) {
    final driver = trip['driver'];
    if (driver is! Map) return null;
    return _nameOf(driver['user']) ?? _nameOf(driver);
  }

  String _fmtDate(dynamic value) {
    if (value is! String || value.isEmpty) return '–';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '–';
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  String _formatKz(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }
}
