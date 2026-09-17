import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_add_driver_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/widgets/admin_driver_edit_dialog.dart';
import 'package:kupon_office_admin/features/admin/presentation/widgets/admin_driver_documents.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDriversPage extends StatefulWidget {
  const AdminDriversPage({super.key});

  @override
  State<AdminDriversPage> createState() => _AdminDriversPageState();
}

class _AdminDriversPageState extends State<AdminDriversPage>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _drivers = [];
  Set<String> _onTripIds = {};
  bool _gridMode = false;
  int _activeTab = 0; // 0: All, 1: Online, 2: Offline, 3: On Trip
  String _selectedCategory = 'All';

  late final AnimationController _pulseController;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _searchCtrl.addListener(() => setState(() {}));
    _statusTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadDrivers(silent: true),
    );
  }

  Future<void> _loadDrivers({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await _db
          .from('drivers')
          .select('*, users!inner(id, name, email, phone, photo_url)')
          .order('created_at', ascending: false);
      final onTrip = await _fetchOnTripDriverIds();

      if (mounted) {
        setState(() {
          _drivers = List<Map<String, dynamic>>.from(data as List);
          _onTripIds = onTrip;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Set<String>> _fetchOnTripDriverIds() async {
    try {
      final fourHoursAgo = DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 4))
          .toIso8601String();
      final rows = await _db
          .from('trips')
          .select('driver_id')
          .inFilter('status', ['accepted', 'in_progress'])
          .gte('created_at', fourHoursAgo);
      return rows
          .map((r) => r['driver_id'] as String?)
          .whereType<String>()
          .toSet();
    } catch (_) {
      return {};
    }
  }

  bool _isOnTrip(Map<String, dynamic> d) =>
      _onTripIds.contains(d['id']) && (d['is_online'] as bool? ?? false);

  String _resolveStatus(Map<String, dynamic> d) {
    if (d['is_blocked'] == true) return 'BLOQUEADO';
    if (!(d['is_approved'] as bool? ?? false)) return 'PENDENTE';
    if (_isOnTrip(d)) return 'EM CORRIDA';
    return (d['is_online'] as bool? ?? false) ? 'ONLINE' : 'OFFLINE';
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _drivers;

    if (_activeTab == 1) {
      list = list
          .where((d) => (d['is_online'] == true) && (d['is_approved'] == true))
          .toList();
    } else if (_activeTab == 2) {
      list = list
          .where((d) => !_isOnTrip(d) && d['is_online'] == false)
          .toList();
    } else if (_activeTab == 3) {
      list = list.where(_isOnTrip).toList();
    }

    if (_selectedCategory != 'All') {
      list = list.where((d) {
        final cat = (d['category'] as String? ?? '').toLowerCase();
        return cat == _selectedCategory.toLowerCase();
      }).toList();
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) {
        final user = d['users'] as Map<String, dynamic>? ?? {};
        final name = (user['name'] as String? ?? '').toLowerCase();
        final plate = (d['vehicle_plate'] as String? ?? '').toLowerCase();
        return name.contains(q) || plate.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _searchCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalOnline = _drivers
        .where((d) => d['is_approved'] == true && d['is_online'] == true)
        .length;
    final totalPending = _drivers
        .where((d) => d['is_approved'] == false)
        .length;
    final totalOnTrip = _drivers.where(_isOnTrip).length;

    double sumRating = 0;
    int ratedCount = 0;
    for (final d in _drivers) {
      final r = d['rating'] as num?;
      if (r != null) {
        sumRating += r;
        ratedCount++;
      }
    }
    final avgRating = ratedCount > 0
        ? (sumRating / ratedCount).toStringAsFixed(2)
        : '4.85';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: _loading
          ? const KuponLoader()
          : RefreshIndicator(
              onRefresh: _loadDrivers,
              color: AppTheme.primaryContainer,
              backgroundColor: AppTheme.surfaceContainerLow,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildStatsRow(
                      totalOnline,
                      avgRating,
                      totalOnTrip,
                      totalPending,
                    ),
                    const SizedBox(height: 24),
                    _buildSearchAndFilters(),
                    const SizedBox(height: 20),
                    _buildDriversList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Header
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestão de Motoristas',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Monitore e gerencie ${_drivers.length} motoristas na sua frota.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        _buildAddButton(),
      ],
    );
  }

  Widget _buildAddButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final created = await showAddDriverDialog(context);
          if (created == true && mounted) {
            _loadDrivers();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Motorista criado e aprovado com sucesso'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Color(0xFF2E7D32),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryContainer.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_add_rounded,
                size: 16,
                color: Colors.black,
              ),
              const SizedBox(width: 8),
              Text(
                'Adicionar Motorista',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Stats Row
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildStatsRow(int online, String avgRating, int onTrip, int pending) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 3 * 16) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              width: cardWidth,
              label: 'ONLINE AGORA',
              value: '$online',
              desc: 'Motoristas disponíveis',
              valueColor: AppTheme.primaryContainer,
              icon: Icons.wifi_rounded,
              iconColor: AppTheme.primaryContainer,
            ),
            _buildStatCard(
              width: cardWidth,
              label: 'AVALIAÇÃO MÉDIA',
              value: avgRating,
              desc: 'de 5.0 estrelas',
              valueColor: AppTheme.tertiary,
              icon: Icons.star_rounded,
              iconColor: AppTheme.tertiary,
            ),
            _buildStatCard(
              width: cardWidth,
              label: 'EM CORRIDAS',
              value: '$onTrip',
              desc:
                  'Ocupação: ${(onTrip / (online > 0 ? online : 1) * 100).toStringAsFixed(0)}%',
              valueColor: AppTheme.onSurfaceVariant,
              icon: Icons.directions_car_rounded,
              iconColor: AppTheme.onSurfaceVariant,
            ),
            _buildStatCard(
              width: cardWidth,
              label: 'APROVAÇÃO PENDENTE',
              value: '$pending',
              desc: 'Aguardando revisão',
              valueColor: AppTheme.errorContainer,
              icon: Icons.pending_actions_rounded,
              iconColor: AppTheme.errorContainer,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required double width,
    required String label,
    required String value,
    required String desc,
    required Color valueColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: width < 180 ? 180 : width,
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.55),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Search + Filters bar
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              color: AppTheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou placa do veículo...',
              hintStyle: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Tabs + Category filter row
        Row(
          children: [
            // Status tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  _buildTab(0, 'Todos'),
                  _buildTab(1, 'Online'),
                  _buildTab(3, 'Em Corrida'),
                  _buildTab(2, 'Offline'),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Category dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: AppTheme.surfaceContainerLow,
                  icon: Icon(
                    Icons.expand_more_rounded,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                    size: 18,
                  ),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                  onChanged: (String? val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                  items:
                      <String>[
                        'All',
                        'Moto',
                        'Car_Standard',
                        'Car_Comfort',
                        'Car_Luxury',
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value == 'All' ? 'Todos os Tipos' : value,
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Advanced filters button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filtros Avançados',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),
            _buildViewToggle(),
            const SizedBox(width: 14),

            const Spacer(),

            // Results count
            Text(
              '${_filtered.length} resultado${_filtered.length == 1 ? '' : 's'}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppTheme.onPrimaryContainer
                : AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Drivers Table
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildDriversList() {
    final items = _filtered;

    if (items.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: AppTheme.glassCard.copyWith(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 52,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 14),
            Text(
              'Nenhum motorista encontrado',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tente ajustar os filtros ou a busca.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return _gridMode ? _buildDriversGrid(items) : _buildDriversTable(items);
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          _buildModeIcon(
            icon: Icons.grid_view_rounded,
            selected: _gridMode,
            tooltip: 'Vista em grade',
            onTap: () => setState(() => _gridMode = true),
          ),
          const SizedBox(width: 4),
          _buildModeIcon(
            icon: Icons.view_agenda_outlined,
            selected: !_gridMode,
            tooltip: 'Vista em lista',
            onTap: () => setState(() => _gridMode = false),
          ),
        ],
      ),
    );
  }

  Widget _buildModeIcon({
    required IconData icon,
    required bool selected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected
                ? AppTheme.onPrimaryContainer
                : AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildDriversTable(List<Map<String, dynamic>> items) {
    return Container(
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _headerLabel('MOTORISTA')),
                Expanded(flex: 2, child: _headerLabel('VEÍCULO')),
                Expanded(flex: 1, child: _headerLabel('AVALIAÇÃO')),
                Expanded(flex: 1, child: _headerLabel('CORRIDAS')),
                Expanded(flex: 2, child: _headerLabel('STATUS')),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _headerLabel('AÇÕES'),
                  ),
                ),
              ],
            ),
          ),

          // Driver rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: AppTheme.outlineVariant.withValues(alpha: 0.2),
            ),
            itemBuilder: (context, idx) => _buildDriverRow(items[idx]),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversGrid(List<Map<String, dynamic>> items) {
    return Container(
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxis = (constraints.maxWidth / 300).floor().clamp(2, 4);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxis,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              mainAxisExtent: 300,
            ),
            itemCount: items.length,
            itemBuilder: (_, idx) => _buildDriverCard(items[idx]),
          );
        },
      ),
    );
  }

  Widget _buildDriverRow(Map<String, dynamic> d) {
    final user = d['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Motorista';
    final photo = user['photo_url'] as String?;
    final category = d['category'] as String? ?? '–';
    final rating = (d['rating'] as num?)?.toStringAsFixed(1) ?? '–';
    final totalTrips = d['total_trips'] as int? ?? 0;
    final isOnline = d['is_online'] as bool? ?? false;
    final isApproved = d['is_approved'] as bool? ?? false;
    final driverId = d['id'] as String;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Row(
        children: [
          // Driver info
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isApproved
                              ? AppTheme.outlineVariant.withValues(alpha: 0.5)
                              : AppTheme.errorContainer.withValues(alpha: 0.7),
                          width: 2,
                        ),
                        color: AppTheme.surfaceContainerHigh,
                      ),
                      child: ClipOval(
                        child: photo != null && photo.isNotEmpty
                            ? Image.network(
                                photo,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.person_rounded,
                                  size: 22,
                                  color: AppTheme.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                size: 22,
                                color: AppTheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                      ),
                    ),
                    // Online pulse dot
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline
                                  ? const Color(0xFF4CAF50)
                                  : AppTheme.surfaceContainerHigh,
                              border: Border.all(
                                color: AppTheme.surfaceContainerLow,
                                width: 1.5,
                              ),
                              boxShadow: isOnline
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF4CAF50)
                                            .withValues(
                                              alpha:
                                                  _pulseController.value * 0.7,
                                            ),
                                        blurRadius: 6,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '#${driverId.substring(0, 8).toUpperCase()}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              color: AppTheme.onSurfaceVariant.withValues(
                                alpha: 0.45,
                              ),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (!isApproved) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.errorContainer.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PENDENTE',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.errorContainer,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Vehicle type badge
          Expanded(flex: 2, child: _buildCategoryBadge(category)),

          // Rating
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Text(
                  rating,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: AppTheme.primaryContainer,
                ),
              ],
            ),
          ),

          // Total trips
          Expanded(
            flex: 1,
            child: Text(
              '$totalTrips',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.onSurface,
              ),
            ),
          ),

          // Status chip
          Expanded(flex: 2, child: _buildStatusChip(_resolveStatus(d))),

          // Actions
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isApproved) ...[
                  _buildActionIcon(
                    icon: Icons.check_rounded,
                    color: const Color(0xFF4CAF50),
                    onTap: () => _openApprovalReview(d),
                  ),
                  const SizedBox(width: 12),
                ],
                _buildActionIcon(
                  icon: Icons.edit_rounded,
                  color: AppTheme.primaryContainer,
                  onTap: () => _openEditDialog(d),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    final label = _categoryLabel(category);
    final (bg, text) = _categoryColors(category);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: text,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final (bg, fg, dot) = _statusColors(status);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: fg.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  (Color bg, Color fg, Color dot) _statusColors(String status) {
    switch (status) {
      case 'BLOQUEADO':
        return (
          const Color(0xFF93000A).withValues(alpha: 0.15),
          const Color(0xFFFFB4AB),
          const Color(0xFFFFB4AB),
        );
      case 'PENDENTE':
        return (
          AppTheme.errorContainer.withValues(alpha: 0.15),
          AppTheme.errorContainer,
          AppTheme.errorContainer,
        );
      case 'EM CORRIDA':
        return (
          const Color(0xFF4FC3F7).withValues(alpha: 0.12),
          const Color(0xFF4FC3F7),
          const Color(0xFF4FC3F7),
        );
      case 'ONLINE':
        return (
          const Color(0xFF4CAF50).withValues(alpha: 0.1),
          const Color(0xFF4CAF50),
          const Color(0xFF4CAF50),
        );
      default:
        return (
          AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
          AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
          AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
        );
    }
  }

  Widget _buildDriverCard(Map<String, dynamic> d) {
    final user = d['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Motorista';
    final photo = user['photo_url'] as String?;
    final category = d['category'] as String? ?? '–';
    final rating = (d['rating'] as num?)?.toStringAsFixed(1) ?? '–';
    final totalTrips = d['total_trips'] as int? ?? 0;
    final isOnline = d['is_online'] as bool? ?? false;
    final isApproved = d['is_approved'] as bool? ?? false;
    final status = _resolveStatus(d);
    final handle = '@${name.toLowerCase().replaceAll(' ', '')}';

    return Container(
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover banner + identidade sobreposta (estilo do perfil)
          SizedBox(
            height: 92,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, top: 10),
                    child: _buildVehicleBadge(category),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.surfaceContainerHigh,
                              border: Border.all(
                                color: AppTheme.surface,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: photo != null && photo.isNotEmpty
                                  ? Image.network(
                                      photo,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.person_rounded,
                                        size: 22,
                                        color: AppTheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    )
                                  : Icon(
                                      Icons.person_rounded,
                                      size: 22,
                                      color: AppTheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0xFF4CAF88)
                                    : AppTheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: AppTheme.surface,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                isOnline ? 'ON' : 'OFF',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isApproved) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 15,
                                    color: AppTheme.primaryContainer,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              handle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                color: AppTheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Conteúdo flexível
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _cardMeta(
                        icon: Icons.star_rounded,
                        text: rating,
                        color: AppTheme.primaryContainer,
                      ),
                      _cardMeta(
                        icon: Icons.directions_car_rounded,
                        text: '$totalTrips',
                      ),
                      _cardMeta(
                        icon: Icons.category_rounded,
                        text: _categoryLabel(category),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusChip(status),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openEditDialog(d),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primaryContainer,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 13,
                                  color: AppTheme.primaryContainer,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Editar perfil',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isApproved) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openApprovalReview(d),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    size: 13,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Aprovar',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardMeta({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? AppTheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// Opens the document review dialog before approving a pending driver.
  Future<void> _openApprovalReview(Map<String, dynamic> d) {
    final user = d['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Motorista';
    return showDriverApprovalReview(
      context,
      driverId: d['id'] as String,
      userId: user['id'] as String?,
      driverName: name,
      onApprove: () => _toggleApproval(d, true),
    );
  }

  Future<void> _toggleApproval(Map<String, dynamic> d, bool approve) async {
    final id = d['id'] as String;
    final prev = d['is_approved'] as bool? ?? false;
    setState(() => d['is_approved'] = approve);
    try {
      await _db.from('drivers').update({'is_approved': approve}).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Motorista aprovado com sucesso' : 'Aprovação revogada',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: approve
              ? const Color(0xFF2E7D32)
              : AppTheme.errorContainer,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => d['is_approved'] = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao atualizar a aprovação do motorista'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorContainer,
          ),
        );
      }
    }
  }

  Future<void> _openEditDialog(Map<String, dynamic> d) async {
    final changed = await showAdminDriverEditDialog(context, d);
    if (changed == true && mounted) _loadDrivers(silent: true);
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  Widget _headerLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
        letterSpacing: 0.6,
      ),
    );
  }

  String _categoryLabel(String c) {
    switch (c.toLowerCase()) {
      case 'moto':
        return 'MOTO';
      case 'car_standard':
        return 'STANDARD';
      case 'car_comfort':
        return 'COMFORT';
      case 'car_luxury':
        return 'LUXURY';
      default:
        return c.toUpperCase();
    }
  }

  String _categoryVehicleAsset(String c) {
    switch (c.toLowerCase()) {
      case 'moto':
        return 'assets/images/moto_topdown.png';
      case 'car_comfort':
        return 'assets/images/car_confort.png';
      case 'car_luxury':
        return 'assets/images/car_luxury.png';
      case 'car_standard':
      default:
        return 'assets/images/car_standard.png';
    }
  }

  Widget _buildVehicleBadge(String category) {
    return Opacity(
      opacity: 0.92,
      child: Image.asset(
        _categoryVehicleAsset(category),
        height: 54,
        fit: BoxFit.contain,
        alignment: Alignment.centerRight,
      ),
    );
  }

  (Color bg, Color text) _categoryColors(String c) {
    switch (c.toLowerCase()) {
      case 'moto':
        return (
          AppTheme.primaryContainer.withValues(alpha: 0.12),
          AppTheme.primaryContainer,
        );
      case 'car_standard':
        return (
          AppTheme.outlineVariant.withValues(alpha: 0.2),
          AppTheme.onSurfaceVariant,
        );
      case 'car_comfort':
        return (AppTheme.tertiary.withValues(alpha: 0.15), AppTheme.tertiary);
      case 'car_luxury':
        return (
          AppTheme.tertiaryContainer.withValues(alpha: 0.2),
          AppTheme.tertiaryContainer,
        );
      default:
        return (AppTheme.surfaceContainerHigh, AppTheme.onSurfaceVariant);
    }
  }
}
