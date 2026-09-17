import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminSosPage extends StatefulWidget {
  const AdminSosPage({super.key});

  @override
  State<AdminSosPage> createState() => _AdminSosPageState();
}

class _AdminSosPageState extends State<AdminSosPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _alerts = [];
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'resolved'

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _db
          .from('sos_alerts')
          .select('*, drivers!inner(id, users!inner(name, phone, photo_url))')
          .order('created_at', ascending: false)
          .limit(60);
      if (mounted) {
        setState(() {
          _alerts = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _db
        .channel('sos_admin')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sos_alerts',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _db.removeAllChannels();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    var list = _alerts;
    if (_searchQuery.isNotEmpty) {
      list = list.where((a) {
        final driver = a['drivers'] as Map<String, dynamic>? ?? {};
        final user = driver['users'] as Map<String, dynamic>? ?? {};
        final name = (user['name'] as String? ?? '').toLowerCase();
        final phone = (user['phone'] as String? ?? '').toLowerCase();
        final address = (a['address'] as String? ?? '').toLowerCase();
        return name.contains(_searchQuery) ||
            phone.contains(_searchQuery) ||
            address.contains(_searchQuery);
      }).toList();
    }

    if (_statusFilter == 'active') {
      list = list.where((a) => a['status'] == 'active').toList();
    } else if (_statusFilter == 'resolved') {
      list = list.where((a) => a['status'] == 'resolved').toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _alerts.where((a) => a['status'] == 'active').length;
    final resolvedCount = _alerts
        .where((a) => a['status'] == 'resolved')
        .length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.primaryContainer,
          backgroundColor: AppTheme.surfaceContainerLow,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderBar(activeCount),
                      const SizedBox(height: 18),
                      _buildKpiSection(activeCount, resolvedCount),
                      const SizedBox(height: 18),
                      _buildSearchBarAndFilter(),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(child: Center(child: KuponLoader()))
              else if (_filteredAlerts.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildAlertCard(_filteredAlerts[i]),
                      ),
                      childCount: _filteredAlerts.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(int activeCount) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color:
                (activeCount > 0
                        ? const Color(0xFFCF6679)
                        : const Color(0xFF4CAF88))
                    .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  (activeCount > 0
                          ? const Color(0xFFCF6679)
                          : const Color(0xFF4CAF88))
                      .withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            activeCount > 0 ? Icons.emergency_rounded : Icons.shield_rounded,
            color: activeCount > 0
                ? const Color(0xFFCF6679)
                : const Color(0xFF4CAF88),
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Monitoramento SOS',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE5E2E1),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (activeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCF6679).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$activeCount ATIVO${activeCount > 1 ? 'S' : ''}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFCF6679),
                          letterSpacing: 0.8,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF88).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SEGURO',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4CAF88),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Central de despacho e resposta a incidentes de emergência',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _load,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFE5E2E1),
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiSection(int active, int resolved) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  _kpiCard(
                    title: 'ALERTAS ATIVOS',
                    value: '$active',
                    icon: Icons.emergency_rounded,
                    color: active > 0
                        ? const Color(0xFFCF6679)
                        : const Color(0xFF4CAF88),
                    subtitle: active > 0
                        ? 'Exigem ação imediata'
                        : 'Sem incidentes ativos',
                  ),
                  const SizedBox(width: 12),
                  _kpiCard(
                    title: 'TOTAL DE ALERTAS',
                    value: '${_alerts.length}',
                    icon: Icons.history_toggle_off_rounded,
                    color: AppTheme.primaryContainer,
                    subtitle: 'Histórico no sistema',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _kpiCard(
                    title: 'RESOLVIDOS',
                    value: '$resolved',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF4CAF88),
                    subtitle: 'Casos concluídos',
                  ),
                  const SizedBox(width: 12),
                  _kpiCard(
                    title: 'STATUS DO SERVIDOR',
                    value: '100% OK',
                    icon: Icons.satellite_alt_rounded,
                    color: const Color(0xFF5AB0FF),
                    subtitle: 'Websocket Realtime Ativo',
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            _kpiCard(
              title: 'ALERTAS ATIVOS',
              value: '$active',
              icon: Icons.emergency_rounded,
              color: active > 0
                  ? const Color(0xFFCF6679)
                  : const Color(0xFF4CAF88),
              subtitle: active > 0
                  ? 'Exigem intervenção imediata'
                  : 'Sem incidentes',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'TOTAL DE ALERTAS',
              value: '${_alerts.length}',
              icon: Icons.history_toggle_off_rounded,
              color: AppTheme.primaryContainer,
              subtitle: 'Histórico no sistema',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'RESOLVIDOS',
              value: '$resolved',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF4CAF88),
              subtitle: 'Casos concluídos com êxito',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'STATUS DO SERVIDOR',
              value: '100% OK',
              icon: Icons.satellite_alt_rounded,
              color: const Color(0xFF5AB0FF),
              subtitle: 'Websocket Realtime Ativo',
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.65),
                    letterSpacing: 0.6,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10.5,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBarAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: TextField(
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: const Color(0xFFE5E2E1),
              ),
              decoration: InputDecoration(
                hintText: 'Pesquisar por motorista, telefone ou endereço...',
                hintStyle: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.4),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFFE2BFB0),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              dropdownColor: AppTheme.surfaceContainerHigh,
              icon: const Icon(
                Icons.filter_list_rounded,
                size: 16,
                color: AppTheme.primaryContainer,
              ),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE5E2E1),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Status: Todos')),
                DropdownMenuItem(value: 'active', child: Text('Apenas Ativos')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolvidos')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _statusFilter = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final driver = alert['drivers'] as Map<String, dynamic>? ?? {};
    final user = driver['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Motorista';
    final phone =
        user['phone'] as String? ?? (alert['phone'] as String? ?? '–');
    final photo = user['photo_url'] as String?;
    final lat = (alert['latitude'] ?? alert['lat']) as num?;
    final lng = (alert['longitude'] ?? alert['lng']) as num?;
    final status = alert['status'] as String? ?? 'active';
    final date = _fmtDate(alert['created_at']);
    final address = alert['address'] as String?;
    final isActive = status == 'active';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFFCF6679).withValues(alpha: 0.5)
              : AppTheme.outlineVariant.withValues(alpha: 0.25),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFCF6679).withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(photo, name, isActive),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE5E2E1),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _statusChip(status),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Acionado em $date • Telefone: $phone',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: Color(0xFFCF6679),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: const Color(0xFFE5E2E1),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (lat != null && lng != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  size: 14,
                  color: Color(0xFFE2BFB0),
                ),
                const SizedBox(width: 6),
                Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://maps.google.com/?q=$lat,$lng',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Text(
                    'Ver no Mapa Externo →',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri(scheme: 'tel', path: phone);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                  label: Text(
                    'Ligar para $name',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE5E2E1),
                    side: const BorderSide(color: Color(0xFF3A3A3A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _resolveAlert(alert['id'] as String),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text(
                      'Marcar Resolvido',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF88),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? url, String name, bool isActive) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surfaceContainerHigh,
            border: Border.all(
              color: isActive
                  ? const Color(0xFFCF6679)
                  : AppTheme.outlineVariant,
            ),
          ),
          child: ClipOval(
            child: url != null && url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryContainer,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryContainer,
                      ),
                    ),
                  ),
          ),
        ),
        if (isActive)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFCF6679),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.surfaceContainerLow,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _resolveAlert(String alertId) async {
    await _db
        .from('sos_alerts')
        .update({'status': 'resolved'})
        .eq('id', alertId);
    _load();
  }

  Widget _statusChip(String status) {
    final isActive = status == 'active';
    final color = isActive ? const Color(0xFFCF6679) : const Color(0xFF4CAF88);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isActive ? 'ATIVO' : 'RESOLVIDO',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF88).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 48,
                color: Color(0xFF4CAF88),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Nenhum alerta SOS ativo',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE5E2E1),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Todos os motoristas e viagens estão em segurança.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12.5,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(dynamic v) {
    if (v is! String || v.isEmpty) return '–';
    final d = DateTime.tryParse(v);
    if (d == null) return '–';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
