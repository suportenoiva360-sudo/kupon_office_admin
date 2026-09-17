import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _db = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _gridMode = false;
  String? _roleFilter;
  List<Map<String, dynamic>> _users = [];

  final Map<String, int> _tripCounts = {};
  final Map<String, double> _userSpent = {};
  final Map<String, double> _ratingSum = {};
  final Map<String, int> _ratingCount = {};

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
    setState(() => _loading = true);
    try {
      final data = await _db
          .from('users')
          .select(
            'id, name, email, phone, photo_url, created_at, role, '
            'province_id, is_blocked',
          )
          .order('created_at', ascending: false)
          .limit(500);

      final since = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 90))
          .toIso8601String();
      final trips = await _db
          .from('trips')
          .select('passenger_id, fare, passenger_rating, created_at, status')
          .gte('created_at', since)
          .limit(1000);

      _tripCounts.clear();
      _userSpent.clear();
      _ratingSum.clear();
      _ratingCount.clear();
      for (final t in trips as List) {
        final pid = t['passenger_id'] as String?;
        if (pid == null) continue;
        _tripCounts[pid] = (_tripCounts[pid] ?? 0) + 1;
        final fare = t['fare'] as num?;
        if (fare != null) {
          _userSpent[pid] = (_userSpent[pid] ?? 0) + fare.toDouble();
        }
        final rating = t['passenger_rating'] as num?;
        if (rating != null) {
          _ratingSum[pid] = (_ratingSum[pid] ?? 0) + rating.toDouble();
          _ratingCount[pid] = (_ratingCount[pid] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _users;
    if (_roleFilter != null) {
      list = list.where((u) => u['role'] == _roleFilter).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((u) {
        final name = (u['name'] as String? ?? '').toLowerCase();
        final email = (u['email'] as String? ?? '').toLowerCase();
        final phone = (u['phone'] as String? ?? '').toLowerCase();
        return name.contains(q) || email.contains(q) || phone.contains(q);
      }).toList();
    }
    return list;
  }

  int _numTrips(Map<String, dynamic> u) => _tripCounts[u['id']] ?? 0;

  Future<void> _openDetail(Map<String, dynamic> user) async {
    final avg = _ratingCount[user['id']];
    await showDialog<void>(
      context: context,
      builder: (_) => _UserDetailDialog(
        user: user,
        tripCount: _tripCounts[user['id']] ?? 0,
        totalSpent: _userSpent[user['id']] ?? 0.0,
        avgRating: avg == null ? null : ((_ratingSum[user['id']] ?? 0) / avg),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = _users.length;
    final passengers = _users.where((u) => u['role'] == 'passenger').length;
    final drivers = _users.where((u) => u['role'] == 'driver').length;
    final thirtyD = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final newUsers = _users.where((u) {
      final c = DateTime.tryParse(u['created_at'] as String? ?? '');
      return c != null && c.isAfter(thirtyD);
    }).length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: _loading
          ? const KuponLoader()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primaryContainer,
              backgroundColor: AppTheme.surfaceContainerLow,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildStatsRow(total, passengers, drivers, newUsers),
                    const SizedBox(height: 24),
                    _buildSearchAndFilters(),
                    const SizedBox(height: 20),
                    _buildUsersList(),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestão de Utilizadores',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Monitore ${_users.length} utilizadores registados na plataforma.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Enviar Notificação',
          onPressed: _openBroadcast,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: AppTheme.primaryContainer,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openBroadcast() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => const _SendNotificationDialog(broadcast: true),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notificação enviada para os utilizadores selecionados',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.primaryContainer,
        ),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Stats Row
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildStatsRow(int total, int passengers, int drivers, int newUsers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 3 * 16) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              width: cardWidth,
              label: 'TOTAL',
              value: '$total',
              desc: 'Contas registadas',
              valueColor: AppTheme.primaryContainer,
              icon: Icons.people_alt_rounded,
              iconColor: AppTheme.primaryContainer,
            ),
            _buildStatCard(
              width: cardWidth,
              label: 'PASSAGEIROS',
              value: '$passengers',
              desc: 'Usuários da app',
              valueColor: AppTheme.tertiary,
              icon: Icons.person_outline_rounded,
              iconColor: AppTheme.tertiary,
            ),
            _buildStatCard(
              width: cardWidth,
              label: 'MOTORISTAS',
              value: '$drivers',
              desc: 'Na frota KupOn',
              valueColor: AppTheme.onSurfaceVariant,
              icon: Icons.directions_car_rounded,
              iconColor: AppTheme.onSurfaceVariant,
            ),
            _buildStatCard(
              width: cardWidth,
              label: 'NOVOS (30 DIAS)',
              value: '$newUsers',
              desc: 'Últimos 30 dias',
              valueColor: AppTheme.secondaryContainer,
              icon: Icons.person_add_rounded,
              iconColor: AppTheme.secondaryContainer,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
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
  // Search + Filters
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSearchAndFilters() {
    return Row(
      spacing: 14,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: AppTheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Pesquisar por nome, e-mail ou telefone...',
              hintStyle: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        _buildRoleDropdown(),
        _buildViewToggle(),
        const Spacer(),
        Text(
          '${_filtered.length} resultado${_filtered.length == 1 ? '' : 's'}',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _roleFilter ?? 'All',
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
          onChanged: (val) =>
              setState(() => _roleFilter = val == 'All' ? null : val),
          items: const [
            DropdownMenuItem(value: 'All', child: Text('Todos os Papéis')),
            DropdownMenuItem(value: 'passenger', child: Text('Passageiros')),
            DropdownMenuItem(value: 'driver', child: Text('Motoristas')),
            DropdownMenuItem(value: 'admin', child: Text('Admins')),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        // color: AppTheme.surfaceContainerLow,
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

  // ──────────────────────────────────────────────────────────────────────────
  // Users List (table / grid)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildUsersList() {
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
              Icons.people_outline_rounded,
              size: 52,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 14),
            Text(
              'Nenhum utilizador encontrado',
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
                fontSize: 12,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return _gridMode ? _buildUsersGrid(items) : _buildUsersTable(items);
  }

  Widget _buildUsersTable(List<Map<String, dynamic>> items) {
    return Container(
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
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
                Expanded(flex: 3, child: _headerLabel('UTILIZADOR')),
                Expanded(flex: 2, child: _headerLabel('PAPEL')),
                Expanded(flex: 1, child: _headerLabel('CORRIDAS')),
                Expanded(flex: 2, child: _headerLabel('TELEFONE')),
                Expanded(flex: 2, child: _headerLabel('REGISTO')),
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
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: AppTheme.outlineVariant.withValues(alpha: 0.2),
            ),
            itemBuilder: (context, idx) => _buildUserRow(items[idx]),
          ),
        ],
      ),
    );
  }

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

  Widget _buildUserRow(Map<String, dynamic> user) {
    final name = user['name'] as String? ?? 'Utilizador';
    final email = user['email'] as String? ?? '–';
    final role = user['role'] as String? ?? 'passenger';
    final phone = user['phone'] as String? ?? '–';
    final blocked = user['is_blocked'] == true;

    return InkWell(
      onTap: () => _openDetail(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _avatar(user, 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (blocked) ...[
                              const SizedBox(width: 6),
                              _blockedBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: AppTheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _roleBadge(role),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${_numTrips(user)}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                phone,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _fmtDate(user['created_at']),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: Tooltip(
                  message: 'Ver detalhes',
                  child: InkWell(
                    onTap: () => _openDetail(user),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryContainer.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: AppTheme.secondaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersGrid(List<Map<String, dynamic>> items) {
    return Container(
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxis = (constraints.maxWidth / 280).floor().clamp(2, 5);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxis,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              mainAxisExtent: 230,
            ),
            itemCount: items.length,
            itemBuilder: (_, idx) => _buildUserCard(items[idx]),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name = user['name'] as String? ?? 'Utilizador';
    final email = user['email'] as String? ?? '–';
    final role = user['role'] as String? ?? 'passenger';
    final phone = user['phone'] as String? ?? '–';
    final blocked = user['is_blocked'] == true;

    return InkWell(
      onTap: () => _openDetail(user),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: blocked
                ? AppTheme.errorContainer.withValues(alpha: 0.6)
                : AppTheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(user, 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _roleBadge(role),
                          if (blocked) _blockedBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            _cardInfoRow(Icons.email_outlined, email),
            const SizedBox(height: 6),
            _cardInfoRow(Icons.phone_outlined, phone),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_numTrips(user)} corridas',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _avatar(Map<String, dynamic> user, double size) {
    final photo = user['photo_url'] as String?;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: ClipOval(
        child: photo != null && photo.isNotEmpty
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.person_rounded, color: Color(0xFFE2BFB0)),
              )
            : const Icon(Icons.person_rounded, color: Color(0xFFE2BFB0)),
      ),
    );
  }

  Widget _roleBadge(String role) {
    Color color;
    String label;
    switch (role) {
      case 'admin':
        color = const Color(0xFFFF6B00);
        label = 'Admin';
        break;
      case 'driver':
        color = const Color(0xFFFFB693);
        label = 'Motorista';
        break;
      default:
        color = const Color(0xFF4CAF88);
        label = 'Passageiro';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  Widget _blockedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'BLOQUEADO',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFB4AB),
        ),
      ),
    );
  }

  String _fmtDate(dynamic v) {
    if (v is! String || v.isEmpty) return '–';
    final d = DateTime.tryParse(v);
    if (d == null) return '–';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

// ──────────────────────────────────────────────────────────────────────────
// User detail dialog
// ──────────────────────────────────────────────────────────────────────────

class _UserDetailDialog extends StatefulWidget {
  const _UserDetailDialog({
    required this.user,
    required this.tripCount,
    required this.totalSpent,
    this.avgRating,
  });

  final Map<String, dynamic> user;
  final int tripCount;
  final double totalSpent;
  final double? avgRating;

  @override
  State<_UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends State<_UserDetailDialog> {
  final _db = Supabase.instance.client;

  bool _loading = true;
  List<Map<String, dynamic>> _trips = [];
  Map<String, dynamic>? _plan;
  int _ticketCount = 0;

  Map<String, dynamic> get _user => widget.user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final trips = await _db
          .from('trips')
          .select(
            'id, status, category, created_at, pickup_name, destination_name, fare, completed_at',
          )
          .eq('passenger_id', _user['id'])
          .order('created_at', ascending: false)
          .limit(30);
      final plan = await _db
          .from('subscriptions')
          .select('*, subscription_plans(name)')
          .eq('user_id', _user['id'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final tickets = await _db
          .from('support_tickets')
          .select('id')
          .eq('user_id', _user['id']);
      if (mounted) {
        setState(() {
          _trips = List<Map<String, dynamic>>.from(trips as List);
          _plan = plan;
          _ticketCount = (tickets as List).length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error
            ? AppTheme.errorContainer
            : const Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _user['role'] as String? ?? 'passenger';
    final blocked = _user['is_blocked'] == true;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    color: AppTheme.primaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Detalhes do Utilizador',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const KuponLoader()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailHeader(),
                          const SizedBox(height: 20),
                          _detailStatsGrid(),
                          const SizedBox(height: 20),
                          _cardSection('Métricas da Conta', [
                            _metricRow(
                              Icons.email_outlined,
                              'Endereço de E-mail',
                              _user['email'] as String? ?? '–',
                            ),
                            _metricRow(
                              Icons.phone_outlined,
                              'Numero de Telefone',
                              _user['phone'] as String? ?? '–',
                            ),
                            _metricRow(
                              Icons.calendar_today_outlined,
                              'Data de Registo',
                              _fmtDate(_user['created_at']),
                            ),
                          ]),
                          if (_plan != null &&
                              _plan!['subscription_plans'] != null) ...[
                            const SizedBox(height: 20),
                            _planCard(_plan!),
                          ],
                          if (_ticketCount > 0) ...[
                            const SizedBox(height: 20),
                            _ticketCard(),
                          ],
                          const SizedBox(height: 20),
                          _actionsSection(role, blocked),
                          const SizedBox(height: 24),
                          Text(
                            'Histórico de Corridas',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._trips.isEmpty
                              ? [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: AppTheme.glassCard.copyWith(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Este utilizador ainda não realizou corridas.',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 12,
                                        color: AppTheme.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ]
                              : _trips.map(_tripItem).toList(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailHeader() {
    final name = _user['name'] as String? ?? 'Utilizador';
    final role = _user['role'] as String? ?? 'passenger';
    final blocked = _user['is_blocked'] == true;
    return Row(
      children: [
        _avatar(_user, 60),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [_roleBadge(role), if (blocked) _blockedBadge()],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailStatsGrid() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _miniStat(
          icon: Icons.route_rounded,
          label: 'CORRIDAS',
          value: '${widget.tripCount}',
        ),
        _miniStat(
          icon: Icons.account_balance_wallet_outlined,
          label: 'TOTAL GASTO',
          value: '${widget.totalSpent.toStringAsFixed(0)} Kz',
        ),
        _miniStat(
          icon: Icons.star_rounded,
          label: 'AVALIAÇÃO',
          value: widget.avgRating == null
              ? '–'
              : widget.avgRating!.toStringAsFixed(1),
        ),
      ],
    );
  }

  Widget _miniStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primaryContainer),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _metricRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFFB693), size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

  Widget _planCard(Map<String, dynamic> sub) {
    final plan = sub['subscription_plans'] as Map<String, dynamic>? ?? {};
    final planName = plan['name'] as String? ?? 'Plano';
    final endDate = _fmtDate(sub['end_date']);
    final status = sub['status'] as String? ?? 'active';
    return _cardSection('Subscrição Ativa', [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: AppTheme.tertiary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Validade: $endDate · ${status.toUpperCase()}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _ticketCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: AppTheme.secondaryContainer,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$_ticketCount chamado${_ticketCount == 1 ? '' : 's'} de suporte',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
          ),
          Text(
            'Ver no Suporte',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsSection(String role, bool blocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Painel de Ações',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _actionButton(
              icon: Icons.edit_outlined,
              label: 'Editar Contacto',
              onTap: _editContact,
            ),
            _actionButton(
              icon: Icons.swap_horiz_rounded,
              label: 'Alterar Papel',
              onTap: () => _changeRole(role),
            ),
            _actionButton(
              icon: Icons.notifications_active_outlined,
              label: 'Enviar Notificação',
              onTap: _sendNotification,
            ),
            _actionButton(
              icon: blocked ? Icons.lock_open_rounded : Icons.block_rounded,
              label: blocked ? 'Desbloquear' : 'Restringir Utilizador',
              danger: true,
              onTap: () => _toggleBlock(blocked),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: danger
              ? AppTheme.errorContainer.withValues(alpha: 0.12)
              : AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: danger
                ? AppTheme.errorContainer
                : AppTheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: danger ? const Color(0xFFFFB4AB) : const Color(0xFFE2BFB0),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: danger
                    ? const Color(0xFFFFB4AB)
                    : const Color(0xFFE5E2E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripItem(Map<String, dynamic> trip) {
    final status = trip['status'] as String? ?? 'pending';
    final statusColor = _tripStatusColor(status);
    final pickup = trip['pickup_name'] as String? ?? 'Origem';
    final dest = trip['destination_name'] as String? ?? 'Destino';
    final category = trip['category'] as String? ?? '–';
    final fare = trip['fare'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard.copyWith(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _statusLabel(status),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pickup → $dest',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtDate(trip['created_at'])} · $category',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            fare != null ? '${fare.toStringAsFixed(0)} Kz' : '–',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Color _tripStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF4CAF88);
      case 'in_progress':
        return const Color(0xFF64B5F6);
      case 'accepted':
        return const Color(0xFFFFB693);
      case 'pending':
        return const Color(0xFFFFC107);
      case 'cancelled':
        return const Color(0xFFCF6679);
      default:
        return AppTheme.onSurfaceVariant;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'CONCLUÍDA';
      case 'in_progress':
        return 'EM CURSO';
      case 'accepted':
        return 'ACEITE';
      case 'pending':
        return 'PENDENTE';
      case 'cancelled':
        return 'CANCELADA';
      default:
        return status.toUpperCase();
    }
  }

  Widget _avatar(Map<String, dynamic> user, double size) {
    final photo = user['photo_url'] as String?;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: ClipOval(
        child: photo != null && photo.isNotEmpty
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.person_rounded, color: Color(0xFFE2BFB0)),
              )
            : const Icon(Icons.person_rounded, color: Color(0xFFE2BFB0)),
      ),
    );
  }

  Widget _roleBadge(String role) {
    Color color;
    String label;
    switch (role) {
      case 'admin':
        color = const Color(0xFFFF6B00);
        label = 'Admin';
        break;
      case 'driver':
        color = const Color(0xFFFFB693);
        label = 'Motorista';
        break;
      default:
        color = const Color(0xFF4CAF88);
        label = 'Passageiro';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  Widget _blockedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'BLOQUEADO',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFB4AB),
        ),
      ),
    );
  }

  Future<void> _sendNotification() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _SendNotificationDialog(
        userId: (_user['id'] as String?) ?? '',
        userName: _user['name'] as String? ?? 'Utilizador',
      ),
    );
    if (sent == true) {
      _snack('Notificação enviada para ${_user['name'] ?? 'o utilizador'}');
    }
  }

  Future<void> _editContact() async {
    final nameCtrl = TextEditingController(
      text: _user['name'] as String? ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: _user['phone'] as String? ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainer,
        title: Text(
          'Editar Contacto',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: AppTheme.onSurface,
              ),
              decoration: const InputDecoration(labelText: 'Nome completo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: AppTheme.onSurface,
              ),
              decoration: const InputDecoration(labelText: 'Telefone'),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Guardar',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (saved != true) return;

    try {
      await _db
          .from('users')
          .update({
            'name': nameCtrl.text.trim(),
            'phone': phoneCtrl.text.trim(),
          })
          .eq('id', _user['id']);
      if (mounted) {
        setState(() {
          _user['name'] = nameCtrl.text.trim();
          _user['phone'] = phoneCtrl.text.trim();
        });
        _snack('Contacto atualizado com sucesso');
      }
    } catch (_) {
      _snack('Falha ao atualizar o contacto', error: true);
    }
  }

  Future<void> _changeRole(String currentRole) async {
    final selected = currentRole == 'passenger' ? 'admin' : 'passenger';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        title: Text(
          'Alterar Papel',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.onSurface,
          ),
        ),
        content: Text(
          'Mudar ${_user['name']} de "${currentRole == 'passenger' ? 'Passageiro' : 'Admin'}" '
          'para "${selected == 'passenger' ? 'Passageiro' : 'Admin'}"?',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Confirmar',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _db.from('users').update({'role': selected}).eq('id', _user['id']);
      if (mounted) {
        setState(() => _user['role'] = selected);
        _snack('Papel alterado com sucesso');
      }
    } catch (_) {
      _snack('Falha ao alterar o papel', error: true);
    }
  }

  Future<void> _toggleBlock(bool blocked) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        title: Text(
          blocked ? 'Desbloquear Utilizador?' : 'Restringir Utilizador?',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.onSurface,
          ),
        ),
        content: Text(
          blocked
              ? 'Este utilizador poderá voltar a iniciar viagens.'
              : 'O utilizador não poderá iniciar novas viagens enquanto estiver restrito.',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  blocked ? 'Desbloquear' : 'Restringir',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFCF6679),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _db.rpc(
        'admin_set_user_blocked',
        params: {'p_user_id': _user['id'], 'p_blocked': !blocked},
      );
      if (mounted) {
        setState(() => _user['is_blocked'] = !blocked);
        _snack(blocked ? 'Utilizador desbloqueado' : 'Utilizador restringido');
      }
    } catch (e) {
      _snack('Falha ao atualizar o bloqueio: ${e.toString()}', error: true);
    }
  }

  String _fmtDate(dynamic v) {
    if (v is! String || v.isEmpty) return '–';
    final d = DateTime.tryParse(v);
    if (d == null) return '–';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _SendNotificationDialog extends StatefulWidget {
  const _SendNotificationDialog({
    this.userId,
    this.userName,
    this.broadcast = false,
  });

  final String? userId;
  final String? userName;
  final bool broadcast;

  @override
  State<_SendNotificationDialog> createState() =>
      _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<_SendNotificationDialog> {
  final _db = Supabase.instance.client;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _category = 'general';
  String? _broadcastRole;
  bool _sending = false;

  static const Map<String, String> _categories = {
    'general': 'Geral (sistema)',
    'promos': 'Promoções',
    'rides': 'Viagens',
    'payments': 'Pagamentos',
    'chat': 'Suporte / Chat',
  };

  static const List<(String?, String)> _broadcastTargets = [
    (null, 'Todos'),
    ('passenger', 'Passageiros'),
    ('driver', 'Motoristas'),
    ('admin', 'Administradores'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o título e a mensagem.'),
          backgroundColor: AppTheme.errorContainer,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      if (widget.broadcast) {
        var query = _db.from('users').select('id')..limit(1000);
        if (_broadcastRole != null) {
          query = query.eq('role', _broadcastRole!);
        }
        final users = await query as List;
        final ids = users
            .map((u) => u['id'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toList();
        if (ids.isEmpty) {
          throw Exception(
            'Nenhum utilizador corresponde ao destino selecionado.',
          );
        }
        await _db
            .from('notifications')
            .insert(
              ids.map((id) {
                return {
                  'user_id': id,
                  'title': title,
                  'body': body,
                  if (_category != 'general') 'category': _category,
                  'data': {},
                };
              }).toList(),
            );
      } else {
        await _db.from('notifications').insert({
          'user_id': widget.userId,
          'title': title,
          'body': body,
          if (_category != 'general') 'category': _category,
          'data': {},
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao enviar notificação: ${e.toString()}'),
          backgroundColor: AppTheme.errorContainer,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: AppTheme.primaryContainer,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            widget.broadcast
                ? 'Enviar Notificação em Massa'
                : 'Enviar Notificação',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.onSurface,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.broadcast)
                Text(
                  'Destinatário: ${widget.userName}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: AppTheme.onSurfaceVariant,
                  ),
                )
              else ...[
                Text(
                  'DESTINATÁRIOS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _broadcastTargets.map((target) {
                    final selected = _broadcastRole == target.$1;
                    return ChoiceChip(
                      label: Text(
                        target.$2,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.black
                              : AppTheme.onSurfaceVariant,
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _broadcastRole = target.$1),
                      selectedColor: AppTheme.primaryContainer,
                      backgroundColor: AppTheme.surfaceContainerLow,
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _titleCtrl,
                maxLength: 80,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: AppTheme.onSurface,
                ),
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyCtrl,
                maxLines: 4,
                maxLength: 500,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: AppTheme.onSurface,
                ),
                decoration: const InputDecoration(
                  labelText: 'Mensagem',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'CATEGORIA',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.entries.map((entry) {
                  final selected = _category == entry.key;
                  return ChoiceChip(
                    label: Text(
                      entry.value,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.black
                            : AppTheme.onSurfaceVariant,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = entry.key),
                    selectedColor: AppTheme.primaryContainer,
                    backgroundColor: AppTheme.surfaceContainerLow,
                    showCheckmark: false,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _sending ? null : () => Navigator.pop(context, false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryContainer,
                foregroundColor: Colors.black,
                minimumSize: const Size(64, 40),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                _sending ? 'A enviar...' : 'Enviar',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
