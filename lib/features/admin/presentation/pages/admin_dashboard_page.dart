import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/providers/map_style_provider.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:kupon_office_admin/features/admin/presentation/widgets/admin_driver_edit_dialog.dart';
import 'package:kupon_office_admin/features/admin/presentation/widgets/admin_export_dialog.dart';
import 'package:kupon_office_admin/features/admin/services/dashboard_export_service.dart';
import 'package:kupon_office_admin/repositories/dashboard_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  final _mapController = MapController();
  final _channels = <RealtimeChannel>[];
  Timer? _refreshDebounce;

  bool _loading = true;
  bool _loadFailed = false;
  bool _lastFailedNotified = false;
  int _revenue30d = 0;
  int _prevRevenue30d = 0;
  int _trips24h = 0;
  int _prevTrips24h = 0;
  int _onlineDrivers = 0;
  int _approvedDrivers = 0;
  int _activeUsers = 0;
  int _newUsers30d = 0;
  int _prevNewUsers30d = 0;
  int _pendingDrivers = 0;
  int _openTickets = 0;
  List<DailyPoint> _daily = [];
  List<DashAlert> _alerts = [];
  List<_DashMapDriver> _liveDrivers = [];
  _DashMapDriver? _hoveredDriver;
  int? _selectedDay;
  final _repo = DashboardRepository();

  // ── Período / intervalo ────────────────────────────────────
  late DateTimeRange _range;
  String _periodLabel = 'Últimos 30 Dias';

  // ── Leaderboard ────────────────────────────────────────────
  String _lbPeriod = 'all';
  String _lbSort = 'trips';
  String _lbCategory = 'all';
  String _lbSearch = '';
  bool _lbLoading = false;
  List<Map<String, dynamic>> _lbData = [];
  final _lbSearchCtrl = TextEditingController();

  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  static const _luanda = LatLng(-8.8390, 13.2894);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(
      start: today.subtract(const Duration(days: 30)),
      end: now,
    );
    _loadData();
    _subscribeDrivers();
    _setupRealtime();
  }

  void _setupRealtime() {
    // Trips — actualizou receita, corridas e gráfico
    _channels.add(
      _db
          .channel('dash-trips')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'trips',
            callback: (_) => _debouncedRefresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'trips',
            callback: (_) => _debouncedRefresh(),
          )
          .subscribe(),
    );

    // Drivers — online, aprovados, pendentes, top
    _channels.add(
      _db
          .channel('dash-drivers')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'drivers',
            callback: (_) => _debouncedRefresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'drivers',
            callback: (_) => _debouncedRefresh(),
          )
          .subscribe(),
    );

    // Users — utilizadores registados
    _channels.add(
      _db
          .channel('dash-users')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'users',
            callback: (_) => _debouncedRefresh(),
          )
          .subscribe(),
    );

    // Support tickets — tickets abertos
    _channels.add(
      _db
          .channel('dash-tickets')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'support_tickets',
            callback: (_) => _debouncedRefresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'support_tickets',
            callback: (_) => _debouncedRefresh(),
          )
          .subscribe(),
    );

    // SOS alerts — alertas ativos
    _channels.add(
      _db
          .channel('dash-sos')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'sos_alerts',
            callback: (_) => _debouncedRefresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'sos_alerts',
            callback: (_) => _debouncedRefresh(),
          )
          .subscribe(),
    );
  }

  /// Debounce: evita múltiplas refreshes em rajada quando várias linhas
  /// mudam ao mesmo tempo (ex.: batch de inserts).
  void _debouncedRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final snap = await _repo.getSnapshot(
        start: _range.start,
        end: _range.end,
      );
      if (mounted) {
        setState(() {
          _revenue30d = snap.revenue30d;
          _prevRevenue30d = snap.prevRevenue30d;
          _trips24h = snap.trips24h;
          _prevTrips24h = snap.prevTrips24h;
          _onlineDrivers = snap.onlineDrivers;
          _approvedDrivers = snap.approvedDrivers;
          _activeUsers = snap.activeUsers;
          _newUsers30d = snap.newUsers30d;
          _prevNewUsers30d = snap.prevNewUsers30d;
          _pendingDrivers = snap.pendingDrivers;
          _openTickets = snap.openTickets;
          _daily = snap.daily;
          _alerts = snap.alerts;
          _loading = false;
          _loadFailed = snap.hadFailures;
          if (!snap.hadFailures) _lastFailedNotified = false;
        });
        if (snap.hadFailures) _notifyLossOfFreshness();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
        _notifyLossOfFreshness();
      }
    }
    _loadLeaderboard();
  }

  void _onLoadFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Não foi possível atualizar todos os dados. A mostrar os valores '
          'mais recentes disponíveis.',
        ),
        backgroundColor: const Color(0xFFCF6679),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _notifyLossOfFreshness() {
    if (!mounted) return;
    if (_lastFailedNotified) return;
    _lastFailedNotified = true;
    _onLoadFailed();
  }

  DateTimeRange get _lbRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_lbPeriod) {
      case 'today':
        return DateTimeRange(start: today, end: now);
      case 'week':
        return DateTimeRange(
          start: today.subtract(const Duration(days: 7)),
          end: now,
        );
      case 'month':
        return DateTimeRange(
          start: today.subtract(const Duration(days: 30)),
          end: now,
        );
      case 'quarter':
        return DateTimeRange(
          start: today.subtract(const Duration(days: 90)),
          end: now,
        );
      default:
        return DateTimeRange(start: DateTime(2024, 1, 1), end: now);
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _lbLoading = true);
    try {
      final range = _lbRange;
      final data = await _repo.getLeaderboardByPeriod(
        start: range.start,
        end: range.end,
        category: _lbCategory == 'all' ? null : _lbCategory,
      );
      if (mounted) setState(() => _lbData = data);
    } catch (e) {
      debugPrint('[LEADERBOARD ERROR] $e');
      if (mounted) setState(() => _lbData = []);
    }
    if (mounted) setState(() => _lbLoading = false);
  }

  List<Map<String, dynamic>> get _filteredLbData {
    var list = _lbData;
    if (_lbSearch.isNotEmpty) {
      final q = _lbSearch.toLowerCase();
      list = list
          .where((d) => (d['name'] as String? ?? '').toLowerCase().contains(q))
          .toList();
    }
    final sorted = List<Map<String, dynamic>>.from(list);
    switch (_lbSort) {
      case 'revenue':
        sorted.sort(
          (a, b) => (b['period_revenue'] as int).compareTo(
            a['period_revenue'] as int,
          ),
        );
        break;
      case 'rating':
        sorted.sort(
          (a, b) => (b['rating'] as double).compareTo(a['rating'] as double),
        );
        break;
      default:
        sorted.sort(
          (a, b) =>
              (b['period_trips'] as int).compareTo(a['period_trips'] as int),
        );
    }
    return sorted;
  }

  Future<void> _loadLiveDrivers() async {
    try {
      final data = await _db
          .from('drivers')
          .select(
            'id, category, current_lat, current_lng, is_online, is_approved, is_blocked, rating, users!inner(name)',
          )
          .eq('is_online', true)
          .eq('is_approved', true)
          .not('current_lat', 'is', null)
          .not('current_lng', 'is', null);
      if (!mounted) return;
      setState(() {
        _liveDrivers = (data as List)
            .map(
              (d) => _DashMapDriver(
                id: d['id'] as String,
                name: ((d['users'] as Map?)?['name'] as String?) ?? 'Motorista',
                category: d['category'] as String?,
                rating: (d['rating'] as num?)?.toDouble() ?? 0,
                position: LatLng(
                  (d['current_lat'] as num).toDouble(),
                  (d['current_lng'] as num).toDouble(),
                ),
              ),
            )
            .toList();
      });
    } catch (_) {}
  }

  void _subscribeDrivers() {
    _channels.add(
      _db
          .channel('dashboard-drivers-preview')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'drivers',
            callback: (payload) async {
              if (!mounted) return;
              final rec = payload.newRecord;
              final id = rec['id'] as String?;
              if (id == null) return;

              final lat = (rec['current_lat'] as num?)?.toDouble();
              final lng = (rec['current_lng'] as num?)?.toDouble();
              final isOnline = rec['is_online'] as bool? ?? false;
              final isApproved = rec['is_approved'] as bool? ?? false;

              // Handle offline / unapproved drivers - no async needed
              if (!isOnline || !isApproved || lat == null || lng == null) {
                if (!mounted) return;
                final removeIdx = _liveDrivers.indexWhere((d) => d.id == id);
                if (removeIdx != -1) {
                  setState(() => _liveDrivers.removeAt(removeIdx));
                }
                return;
              }

              final pos = LatLng(lat, lng);

              // Fetch name from users table (async gap)
              String name = 'Motorista';
              try {
                final u = await _db
                    .from('drivers')
                    .select('users!inner(name)')
                    .eq('id', id)
                    .single();
                name = ((u['users'] as Map?)?['name'] as String?) ?? name;
              } catch (_) {}

              // Re-calculate idx after the await — list may have changed
              if (!mounted) return;
              final currentIdx = _liveDrivers.indexWhere((d) => d.id == id);

              if (currentIdx != -1) {
                setState(() {
                  // Guard against concurrent modification
                  if (currentIdx < _liveDrivers.length) {
                    _liveDrivers[currentIdx] = _liveDrivers[currentIdx]
                        .copyWith(position: pos, name: name);
                  }
                });
              } else {
                setState(
                  () => _liveDrivers.add(
                    _DashMapDriver(
                      id: id,
                      name: name,
                      category: rec['category'] as String?,
                      rating: (rec['rating'] as num?)?.toDouble() ?? 0,
                      position: pos,
                    ),
                  ),
                );
              }
            },
          )
          .subscribe(),
    );

    _loadLiveDrivers();
  }

  @override
  void dispose() {
    for (final ch in _channels) {
      ch.unsubscribe();
    }
    _refreshDebounce?.cancel();
    _pulse.dispose();
    _mapController.dispose();
    _lbSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: _loading
          ? const KuponLoader()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primaryContainer,
              backgroundColor: const Color(0xFF131313),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loadFailed) ...[
                      _buildFreshnessBanner(),
                      const SizedBox(height: 24),
                    ],
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildBentoStatsGrid(),
                    const SizedBox(height: 24),
                    _buildCentralGrid(context),
                    const SizedBox(height: 24),
                    _buildBottomGrid(context),
                  ],
                ),
              ),
            ),
    );
  }

  String _fmtRange(DateTimeRange r) {
    String d(DateTime v) =>
        '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}';
    return '${d(r.start)} – ${d(r.end)}';
  }

  Future<void> _openPeriodPicker() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final presets = <String, DateTimeRange>{
      'Hoje': DateTimeRange(start: today, end: now),
      'Últimos 7 Dias': DateTimeRange(
        start: today.subtract(const Duration(days: 7)),
        end: now,
      ),
      'Últimos 30 Dias': DateTimeRange(
        start: today.subtract(const Duration(days: 30)),
        end: now,
      ),
      'Últimos 90 Dias': DateTimeRange(
        start: today.subtract(const Duration(days: 90)),
        end: now,
      ),
    };

    final selected = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: AppTheme.primaryContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Selecionar período',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE5E2E1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in presets.entries)
              ListTile(
                leading: const Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: Color(0xFFE2BFB0),
                ),
                title: Text(
                  entry.key,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE5E2E1),
                  ),
                ),
                trailing: _periodLabel == entry.key
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppTheme.primaryContainer,
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, entry.value),
              ),
            ListTile(
              leading: const Icon(
                Icons.date_range_rounded,
                size: 18,
                color: Color(0xFFE2BFB0),
              ),
              title: Text(
                'Personalizado...',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE5E2E1),
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || selected == null) return;

    if (selected == 'custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2024, 1, 1),
        lastDate: now,
        initialDateRange: _range,
        helpText: 'Selecionar período',
        saveText: 'Aplicar',
      );
      if (!mounted || picked == null) return;
      final range = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        ),
      );
      setState(() {
        _range = range;
        _periodLabel = _fmtRange(range);
      });
    } else {
      final range = selected as DateTimeRange;
      setState(() {
        _range = range;
        _periodLabel = presets.entries
            .firstWhere(
              (e) => e.value == range,
              orElse: () => presets.entries.first,
            )
            .key;
      });
    }
    _loadData();
  }

  void _openExportDialog() {
    final reportData = DashboardReportData(
      periodName: _periodLabel,
      generatedAt: DateTime.now(),
      revenue30d: _revenue30d,
      prevRevenue30d: _prevRevenue30d,
      trips24h: _trips24h,
      prevTrips24h: _prevTrips24h,
      onlineDrivers: _onlineDrivers,
      approvedDrivers: _approvedDrivers,
      pendingDrivers: _pendingDrivers,
      activeUsers: _activeUsers,
      newUsers30d: _newUsers30d,
      openTickets: _openTickets,
      daily: _daily,
      alerts: _alerts,
      leaderboard: _lbData.isNotEmpty ? _lbData : _filteredLbData,
    );

    AdminExportReportDialog.show(context, reportData);
  }

  Widget _buildFreshnessBanner() {
    const msg =
        'Não foi possível carregar todos os dados. A mostrar os '
        'valores mais recentes disponíveis.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1B21),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFCF6679).withValues(alpha: .5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFCF6679),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                height: 1.4,
                color: const Color(0xFFE6B7BE),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Tentar de novo',
            onPressed: () {
              setState(() {
                _loading = true;
                _loadFailed = false;
              });
              _loadData();
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFCF6679),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visão Geral Operacional',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE5E2E1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Acompanhamento de desempenho em tempo real e saúde do sistema.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openPeriodPicker,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: Color(0xFFE2BFB0),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _periodLabel,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE5E2E1),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: Color(0xFFE2BFB0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openExportDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.download_rounded,
                        size: 14,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Exportar Relatório',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - 3 * 16) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildBentoCard(
              width: cardWidth,
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFFFF6B00),
              label: 'RECEITA TOTAL',
              value: '${formatNumber(_revenue30d)} Kz',
              trend: _trendLabel(_revenue30d, _prevRevenue30d),
              isPositive: _isGrowth(_revenue30d, _prevRevenue30d),
            ),
            _buildBentoCard(
              width: cardWidth,
              icon: Icons.electric_car_rounded,
              iconColor: const Color(0xFFFF6B00),
              label: 'CORRIDAS ATIVAS',
              value: '$_trips24h',
              trend: _trendLabel(_trips24h, _prevTrips24h),
              isPositive: _isGrowth(_trips24h, _prevTrips24h),
            ),
            _buildBentoCard(
              width: cardWidth,
              icon: Icons.person_pin_circle_rounded,
              iconColor: const Color(0xFFFFB693),
              label: 'MOTORISTAS ONLINE',
              value: '$_onlineDrivers',
              subLabel: '$_approvedDrivers aprovados',
            ),
            _buildBentoCard(
              width: cardWidth,
              icon: Icons.group_rounded,
              iconColor: const Color(0xFFFFB693),
              label: 'UTILIZADORES REGISTADOS',
              value: '$_activeUsers',
              trend: _trendLabel(_newUsers30d, _prevNewUsers30d),
              isPositive: _isGrowth(_newUsers30d, _prevNewUsers30d),
            ),
          ],
        );
      },
    );
  }

  String _trendLabel(int current, int previous) {
    if (previous <= 0) return '—';
    final pct = (current - previous) / previous * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  bool _isGrowth(int current, int previous) {
    return previous <= 0 || current >= previous;
  }

  Widget _buildBentoCard({
    required double width,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? trend,
    bool? isPositive,
    String? subLabel,
  }) {
    return Container(
      width: width < 200 ? 200 : width,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              if (trend != null && isPositive != null)
                Row(
                  children: [
                    Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isPositive
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFCF6679),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPositive
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFCF6679),
                      ),
                    ),
                  ],
                )
              else if (subLabel != null)
                Text(
                  subLabel,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFE5E2E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVertical = constraints.maxWidth < 800;
        final chartWidth = isVertical
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) * 0.65;
        final alertsWidth = isVertical
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) * 0.35;

        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildChartSection(chartWidth),
            _buildAlertsSection(alertsWidth, context),
          ],
        );
      },
    );
  }

  Widget _buildChartSection(double width) {
    final maxTrips = _daily.fold<int>(0, (m, d) => d.trips > m ? d.trips : m);
    final maxRevenue = _daily.fold<int>(
      0,
      (m, d) => d.revenue > m ? d.revenue : m,
    );
    final maxVal = maxRevenue > maxTrips ? maxRevenue : maxTrips;

    return GestureDetector(
      onTapDown: (details) {
        // Deselect when tapping outside bars
        setState(() => _selectedDay = null);
      },
      child: Container(
        width: width,
        height: 340,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        decoration: AppTheme.glassCard.copyWith(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Corridas vs Receita',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE5E2E1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toque numa barra para ver os valores',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _chartLegendItem('Receita', const Color(0xFFFF6B00)),
                    const SizedBox(width: 16),
                    _chartLegendItem('Corridas', const Color(0xFFA98A7D)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Selected day tooltip
            if (_selectedDay != null && _selectedDay! < _daily.length)
              _buildTooltip(_daily[_selectedDay!]),

            const SizedBox(height: 8),

            // Chart area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTapUp: (details) {
                      final barAreaWidth = constraints.maxWidth;
                      final barStep = barAreaWidth / _daily.length;
                      final idx = (details.localPosition.dx / barStep).floor();
                      if (idx >= 0 && idx < _daily.length) {
                        setState(
                          () => _selectedDay = _selectedDay == idx ? null : idx,
                        );
                      }
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Y-axis labels + grid
                        SizedBox(
                          width: 48,
                          height: constraints.maxHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(5, (i) {
                              final val = maxVal > 0
                                  ? (maxVal * (4 - i) / 4).round()
                                  : 0;
                              return Text(
                                _shortNum(val),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 9,
                                  color: const Color(
                                    0xFFE2BFB0,
                                  ).withValues(alpha: 0.4),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Bars + gridlines
                        Expanded(
                          child: Stack(
                            children: [
                              // Horizontal gridlines
                              ...List.generate(5, (i) {
                                return Positioned(
                                  top: i * (constraints.maxHeight / 4) - 5,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 1,
                                    color: const Color(
                                      0xFFE2BFB0,
                                    ).withValues(alpha: 0.08),
                                  ),
                                );
                              }),

                              // Bars
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(_daily.length, (index) {
                                  final point = _daily[index];
                                  final isSelected = _selectedDay == index;
                                  final revenuePct = maxRevenue > 0
                                      ? (point.revenue / maxRevenue)
                                            .clamp(0.02, 1.0)
                                            .toDouble()
                                      : 0.02;
                                  final tripsPct = maxTrips > 0
                                      ? (point.trips / maxTrips)
                                            .clamp(0.02, 1.0)
                                            .toDouble()
                                      : 0.02;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 350,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              height: isSelected
                                                  ? constraints.maxHeight *
                                                        revenuePct
                                                  : constraints.maxHeight *
                                                        revenuePct,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: isSelected
                                                      ? [
                                                          const Color(
                                                            0xFFFF6B00,
                                                          ),
                                                          const Color(
                                                            0xFFFFB693,
                                                          ),
                                                        ]
                                                      : [
                                                          const Color(
                                                            0xFFFF6B00,
                                                          ).withValues(
                                                            alpha: 0.7,
                                                          ),
                                                          const Color(
                                                            0xFFFFB693,
                                                          ).withValues(
                                                            alpha: 0.7,
                                                          ),
                                                        ],
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                boxShadow: isSelected
                                                    ? [
                                                        BoxShadow(
                                                          color:
                                                              const Color(
                                                                0xFFFF6B00,
                                                              ).withValues(
                                                                alpha: 0.5,
                                                              ),
                                                          blurRadius: 10,
                                                          offset: const Offset(
                                                            0,
                                                            -2,
                                                          ),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Expanded(
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 350,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              height: isSelected
                                                  ? constraints.maxHeight *
                                                        tripsPct
                                                  : constraints.maxHeight *
                                                        tripsPct,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: isSelected
                                                      ? [
                                                          const Color(
                                                            0xFF6E5F57,
                                                          ),
                                                          const Color(
                                                            0xFFA98A7D,
                                                          ),
                                                        ]
                                                      : [
                                                          const Color(
                                                            0xFF6E5F57,
                                                          ).withValues(
                                                            alpha: 0.6,
                                                          ),
                                                          const Color(
                                                            0xFFA98A7D,
                                                          ).withValues(
                                                            alpha: 0.6,
                                                          ),
                                                        ],
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // X-axis labels
            Padding(
              padding: const EdgeInsets.only(left: 56, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_daily.length, (index) {
                  final point = _daily[index];
                  final isLast = index == _daily.length - 1;
                  final isSelected = _selectedDay == index;
                  return Expanded(
                    child: Text(
                      _chartLabel(point.date, isLast),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isSelected
                            ? AppTheme.primaryContainer
                            : const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(DailyPoint point) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tooltipItem(
            '${point.date.day}/${point.date.month}',
            null,
            FontWeight.w600,
            AppTheme.onSurface,
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 20, color: AppTheme.outlineVariant),
          const SizedBox(width: 16),
          _tooltipItem(
            '${point.trips}',
            'corridas',
            FontWeight.w700,
            const Color(0xFFA98A7D),
          ),
          const SizedBox(width: 16),
          _tooltipItem(
            formatNumber(point.revenue),
            'Kz',
            FontWeight.w700,
            const Color(0xFFFF6B00),
          ),
        ],
      ),
    );
  }

  Widget _tooltipItem(
    String value,
    String? suffix,
    FontWeight weight,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: weight,
            color: color,
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 3),
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Text(
              suffix,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _shortNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  String _chartLabel(DateTime date, bool isLast) {
    if (isLast) return 'Hoje';
    return 'D-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _chartLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            color: const Color(0xFFE2BFB0).withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsSection(double width, BuildContext context) {
    final List<_AlertItem> alerts = _alerts
        .map(
          (a) => _AlertItem(
            title: a.title,
            time: a.time,
            description: a.description,
            accentColor: _alertColor(a.kind),
            actions: [
              _AlertAction(
                a.kind == 'approval' ? 'Rever' : 'Ver',
                () => context.go(a.route),
              ),
            ],
          ),
        )
        .toList();

    return Container(
      width: width,
      height: 380,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alertas Recentes',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE5E2E1),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF93000A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_pendingDrivers + _openTickets} URGENTE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFB4AB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 36,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Sem alertas no momento',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: const Color(
                              0xFFE2BFB0,
                            ).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: alerts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final item = alerts[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF201F1F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2A2A2A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 48,
                              decoration: BoxDecoration(
                                color: item.accentColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.title,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFE5E2E1),
                                        ),
                                      ),
                                      Text(
                                        item.time,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 10,
                                          color: const Color(
                                            0xFFE2BFB0,
                                          ).withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 12,
                                      color: const Color(
                                        0xFFE2BFB0,
                                      ).withValues(alpha: 0.8),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.actions != null &&
                                      item.actions!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: item.actions!
                                          .map(
                                            (act) => GestureDetector(
                                              onTap: act.onTap,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      AppTheme.primaryContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  act.label,
                                                  style:
                                                      GoogleFonts.spaceGrotesk(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _alertColor(String kind) {
    switch (kind) {
      case 'sos':
        return const Color(0xFFCF6679);
      case 'withdraw':
        return const Color(0xFFF5C842);
      case 'ticket':
        return const Color(0xFF2196F3);
      default:
        return AppTheme.secondaryContainer;
    }
  }

  Widget _buildBottomGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVertical = constraints.maxWidth < 800;
        final mapWidth = isVertical
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) * 0.65;
        final leaderboardWidth = isVertical
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) * 0.35;

        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildLiveMapPreview(mapWidth, context),
            _buildLeaderboardSection(leaderboardWidth),
          ],
        );
      },
    );
  }

  Widget _buildLiveMapPreview(double width, BuildContext context) {
    final mapStyle = context.watch<MapStyleProvider>();

    return Container(
      width: width,
      height: 360,
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── Real FlutterMap ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _luanda,
              initialZoom: 12.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
              onTap: (_, _) => setState(() => _hoveredDriver = null),
            ),
            children: [
              TileLayer(
                urlTemplate: mapStyle.urlTemplate,
                userAgentPackageName: 'com.kupon.admin',
                maxZoom: 19,
              ),
              // Driver markers
              MarkerLayer(
                markers: _liveDrivers.map((d) {
                  final isSelected = _hoveredDriver?.id == d.id;
                  return Marker(
                    point: d.position,
                    width: isSelected ? 48 : 36,
                    height: isSelected ? 48 : 36,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _hoveredDriver = isSelected ? null : d;
                      }),
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulse ring
                              Container(
                                width:
                                    (isSelected ? 48 : 36) *
                                    (1 + _pulseAnim.value * 0.3),
                                height:
                                    (isSelected ? 48 : 36) *
                                    (1 + _pulseAnim.value * 0.3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _markerColor(d.category).withValues(
                                    alpha: (1 - _pulseAnim.value) * 0.35,
                                  ),
                                ),
                              ),
                              // Marker core
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isSelected ? 34 : 26,
                                height: isSelected ? 34 : 26,
                                decoration: BoxDecoration(
                                  color: _markerColor(d.category),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black45,
                                    width: isSelected ? 2.5 : 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _markerColor(
                                        d.category,
                                      ).withValues(alpha: 0.5),
                                      blurRadius: isSelected ? 14 : 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _markerIcon(d.category),
                                  color: Colors.white,
                                  size: isSelected ? 17 : 13,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Bottom gradient vignette ──
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.surface.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.transparent,
                      AppTheme.surface.withValues(alpha: 0.45),
                    ],
                    stops: const [0.0, 0.15, 0.75, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // ── Top bar: Live badge ──
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated green dot
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, _) => Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4CAF50),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF4CAF50,
                            ).withValues(alpha: _pulseAnim.value * 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AO VIVO · ${_liveDrivers.length} motorista${_liveDrivers.length == 1 ? '' : 's'}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Map style selector (top-right) ──
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: PopupMenuButton<String>(
                tooltip: 'Estilo do mapa',
                onSelected: (v) => mapStyle.setStyle(v),
                icon: Icon(
                  mapStyle.styleIcon(mapStyle.style),
                  color: AppTheme.onSurfaceVariant,
                  size: 18,
                ),
                color: AppTheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                  ),
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
                        const SizedBox(width: 8),
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
                            size: 14,
                            color: AppTheme.primaryContainer,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Selected driver tooltip ──
          if (_hoveredDriver != null)
            Positioned(
              top: 70,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _markerColor(
                          _hoveredDriver!.category,
                        ).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _markerIcon(_hoveredDriver!.category),
                        size: 14,
                        color: _markerColor(_hoveredDriver!.category),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _hoveredDriver!.name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 11,
                              color: AppTheme.primaryContainer,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _hoveredDriver!.rating.toStringAsFixed(1),
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                color: AppTheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom bar: region info + expand button ──
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow.withValues(
                        alpha: 0.92,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_city_rounded,
                          size: 14,
                          color: AppTheme.primaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Luanda · Área Operacional',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Legend pills row
                Row(
                  children: [
                    _mapLegendPill('Standard', const Color(0xFFFF6B00)),
                    const SizedBox(width: 6),
                    _mapLegendPill('Comfort', const Color(0xFF2196F3)),
                    const SizedBox(width: 6),
                    _mapLegendPill('Luxury', const Color(0xFFFFD700)),
                    const SizedBox(width: 10),
                    // Expand button
                    GestureDetector(
                      onTap: () => context.push('/mapa'),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryContainer.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
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

  Widget _mapLegendPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
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

  IconData _markerIcon(String? category) {
    switch (category) {
      case 'moto':
        return Icons.two_wheeler_rounded;
      case 'car_luxury':
        return Icons.directions_car_rounded;
      case 'car_comfort':
      case 'car_standard':
      default:
        return Icons.directions_car_rounded;
    }
  }

  Widget _buildLeaderboardSection(double width) {
    final data = _filteredLbData;
    final top3 = data.length >= 3 ? data.sublist(0, 3) : data;
    final rest = data.length > 3 ? data.sublist(3) : <Map<String, dynamic>>[];
    final maxTrips = data.isNotEmpty ? (data[0]['period_trips'] as int) : 1;

    const medalColors = [
      Color(0xFFFFD700), // gold
      Color(0xFFC0C0C0), // silver
      Color(0xFFCD7F32), // bronze
    ];

    return Container(
      width: width,
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        size: 16,
                        color: Color(0xFFFF6B00),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Classificação dos Motoristas',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE5E2E1),
                        ),
                      ),
                    ),
                    if (_lbLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFFFF6B00),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Period tabs ──
                _buildPeriodTabs(),
                const SizedBox(height: 10),
                // ── Search + Sort row ──
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _lbSearchCtrl,
                          onChanged: (v) => setState(() => _lbSearch = v),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: const Color(0xFFE5E2E1),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar motorista…',
                            hintStyle: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              color: const Color(
                                0xFFE2BFB0,
                              ).withValues(alpha: 0.35),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 14,
                              color: const Color(
                                0xFFE2BFB0,
                              ).withValues(alpha: 0.4),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0E0E0E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF2A2A2A),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF2A2A2A),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF6B00),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _buildSortDropdown()),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Category chips ──
                _buildCategoryChips(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          // ── Body ──
          if (_lbLoading && _lbData.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFFFF6B00),
                ),
              ),
            )
          else if (data.isEmpty)
            _buildLeaderboardEmpty()
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  children: [
                    if (top3.length >= 3) ...[
                      _buildPodium(top3, medalColors),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFF2A2A2A)),
                      const SizedBox(height: 10),
                    ],
                    ...List.generate(rest.length, (i) {
                      final d = rest[i];
                      final pos = top3.length + i + 1;
                      return _buildLbRow(d, pos, maxTrips, medalColors);
                    }),
                    if (rest.isEmpty && top3.length < 3)
                      ...List.generate(top3.length, (i) {
                        final d = top3[i];
                        return _buildLbRow(d, i + 1, maxTrips, medalColors);
                      }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Period tabs ──────────────────────────────────────────────
  Widget _buildPeriodTabs() {
    final periods = [
      ('Hoje', 'today'),
      ('Semana', 'week'),
      ('Mês', 'month'),
      ('3 Meses', 'quarter'),
      ('Todos', 'all'),
    ];
    return Row(
      children: periods.map((p) {
        final active = _lbPeriod == p.$2;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _lbPeriod = p.$2);
              _loadLeaderboard();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFF6B00).withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: active
                      ? const Color(0xFFFF6B00).withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                p.$1,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Sort dropdown ────────────────────────────────────────────
  Widget _buildSortDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _lbSort,
          isDense: true,
          isExpanded: true,
          icon: Icon(
            Icons.unfold_more_rounded,
            size: 12,
            color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
          ),
          dropdownColor: const Color(0xFF1C1B1B),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            color: const Color(0xFFE5E2E1),
          ),
          items: const [
            DropdownMenuItem(value: 'trips', child: Text('Corridas')),
            DropdownMenuItem(value: 'revenue', child: Text('Receita')),
            DropdownMenuItem(value: 'rating', child: Text('Rating')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _lbSort = v);
          },
        ),
      ),
    );
  }

  // ── Category chips ───────────────────────────────────────────
  Widget _buildCategoryChips() {
    final cats = [
      ('Todos', 'all'),
      ('🚗 Standard', 'car_standard'),
      ('🚙 Comfort', 'car_comfort'),
      ('✨ Luxo', 'car_luxury'),
      ('🏍 Moto', 'moto'),
    ];
    return SizedBox(
      height: 26,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final active = _lbCategory == cats[i].$2;
          return GestureDetector(
            onTap: () {
              setState(() => _lbCategory = cats[i].$2);
              _loadLeaderboard();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFF6B00).withValues(alpha: 0.12)
                    : const Color(0xFF201F1F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active
                      ? const Color(0xFFFF6B00).withValues(alpha: 0.3)
                      : const Color(0xFF2A2A2A),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                cats[i].$1,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Podium (top 3) ──────────────────────────────────────────
  Widget _buildPodium(
    List<Map<String, dynamic>> top3,
    List<Color> medalColors,
  ) {
    final avatars = [72.0, 88.0, 64.0]; // 2nd, 1st, 3rd sizes
    final podium = [top3[1], top3[0], top3[2]];
    final colors = [medalColors[1], medalColors[0], medalColors[2]];
    final labels = ['2', '1', '3'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final d = podium[i];
        final c = colors[i];
        final sz = avatars[i];
        final name = d['name'] as String? ?? '';
        final trips = d['period_trips'] as int? ?? 0;
        final revenue = d['period_revenue'] as int? ?? 0;
        final rating = (d['rating'] as num?)?.toDouble() ?? 0.0;
        final photoUrl = d['photo_url'] as String? ?? '';

        return Expanded(
          child: GestureDetector(
            onTap: () => _openLeaderboardDriver(d),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: sz,
                      height: sz,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            c.withValues(alpha: 0.3),
                            c.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: c.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.person_rounded,
                            size: sz * 0.45,
                            color: c,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [c, c.withValues(alpha: 0.7)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF131313),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            labels[i],
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: i == 1
                                  ? const Color(0xFF3D2800)
                                  : const Color(0xFF1A1A1A),
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE5E2E1),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatNumber(trips)} corridas',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatNumber(revenue)} Kz',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 9, color: c),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: c,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── List row (4th+) ─────────────────────────────────────────
  Widget _buildLbRow(
    Map<String, dynamic> d,
    int pos,
    int maxTrips,
    List<Color> medalColors,
  ) {
    final name = d['name'] as String? ?? '';
    final trips = d['period_trips'] as int? ?? 0;
    final revenue = d['period_revenue'] as int? ?? 0;
    final rating = (d['rating'] as num?)?.toDouble() ?? 0.0;
    final photoUrl = d['photo_url'] as String? ?? '';
    final category = d['category'] as String?;
    final progress = maxTrips > 0 ? (trips / maxTrips).clamp(0.0, 1.0) : 0.0;
    final color = pos <= 3 ? medalColors[pos - 1] : const Color(0xFFFF6B00);

    return GestureDetector(
      onTap: () => _openLeaderboardDriver(d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: pos <= 3 ? color.withValues(alpha: 0.04) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Position
            SizedBox(
              width: 20,
              child: Text(
                '$pos',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: pos <= 3
                      ? color
                      : const Color(0xFFE2BFB0).withValues(alpha: 0.35),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Avatar
            ClipOval(
              child: Image.network(
                photoUrl,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2A2A2A),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: Color(0xFFE2BFB0),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name + category + progress bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE5E2E1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _categoryLabel(category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          color: const Color(
                            0xFFE2BFB0,
                          ).withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: const Color(0xFF2A2A2A),
                            valueColor: AlwaysStoppedAnimation(
                              color.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatNumber(trips),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE5E2E1),
                  ),
                ),
                Text(
                  '${formatNumber(revenue)} Kz',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Rating
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 9, color: color),
                  const SizedBox(width: 2),
                  Text(
                    rating.toStringAsFixed(1),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String? cat) {
    switch (cat) {
      case 'car_standard':
        return 'Standard';
      case 'car_comfort':
        return 'Comfort';
      case 'car_luxury':
        return 'Luxo';
      case 'moto':
        return 'Moto';
      default:
        return '–';
    }
  }

  void _openLeaderboardDriver(Map<String, dynamic> d) async {
    final driverId = d['driver_id'] as String?;
    if (driverId == null) return;
    try {
      final data = await _db
          .from('drivers')
          .select(
            '*, users!inner(id, name, email, phone, photo_url, created_at)',
          )
          .eq('id', driverId)
          .single();
      if (mounted) showAdminDriverEditDialog(context, data);
    } catch (_) {}
  }

  Widget _buildLeaderboardEmpty() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.leaderboard_rounded,
            size: 32,
            color: const Color(0xFFE2BFB0).withValues(alpha: 0.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Sem dados para este período',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: const Color(0xFFE2BFB0).withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tente outro período ou categoria',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: const Color(0xFFE2BFB0).withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertItem {
  final String title;
  final String time;
  final String description;
  final Color accentColor;
  final List<_AlertAction>? actions;

  const _AlertItem({
    required this.title,
    required this.time,
    required this.description,
    required this.accentColor,
    this.actions,
  });
}

class _AlertAction {
  final String label;
  final VoidCallback onTap;

  const _AlertAction(this.label, this.onTap);
}

class _DashMapDriver {
  final String id;
  final String name;
  final String? category;
  final double rating;
  final LatLng position;

  const _DashMapDriver({
    required this.id,
    required this.name,
    this.category,
    required this.rating,
    required this.position,
  });

  _DashMapDriver copyWith({LatLng? position, String? name}) => _DashMapDriver(
    id: id,
    name: name ?? this.name,
    category: category,
    rating: rating,
    position: position ?? this.position,
  );
}
