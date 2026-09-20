import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPromocoesPage extends StatefulWidget {
  const AdminPromocoesPage({super.key});

  @override
  State<AdminPromocoesPage> createState() => _AdminPromocoesPageState();
}

class _AdminPromocoesPageState extends State<AdminPromocoesPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _promos = [];

  String _searchQuery = '';
  String _statusFilter =
      'all'; // 'all', 'active', 'inactive', 'percentage', 'fixed'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _db
          .from('promotions')
          .select('*')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _promos = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredPromos {
    var list = _promos;
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) {
        final code = (p['code'] as String? ?? '').toLowerCase();
        final name = (p['name'] as String? ?? '').toLowerCase();
        final description = (p['description'] as String? ?? '').toLowerCase();
        return code.contains(_searchQuery) ||
            name.contains(_searchQuery) ||
            description.contains(_searchQuery);
      }).toList();
    }

    if (_statusFilter == 'active') {
      list = list.where((p) => p['is_active'] == true).toList();
    } else if (_statusFilter == 'inactive') {
      list = list.where((p) => p['is_active'] != true).toList();
    } else if (_statusFilter == 'percentage') {
      list = list.where((p) => p['discount_type'] == 'percentage').toList();
    } else if (_statusFilter == 'fixed') {
      list = list.where((p) => p['discount_type'] == 'fixed').toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _promos.where((p) => p['is_active'] == true).length;
    final totalUses = _promos.fold<int>(
      0,
      (sum, p) => sum + ((p['current_uses'] as num?)?.toInt() ?? 0),
    );
    final percentageCount = _promos
        .where((p) => p['discount_type'] == 'percentage')
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
                      _buildHeaderBar(),
                      const SizedBox(height: 18),
                      _buildKpiSection(activeCount, totalUses, percentageCount),
                      const SizedBox(height: 18),
                      _buildSearchBarAndFilter(),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(child: Center(child: KuponLoader()))
              else if (_filteredPromos.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPromoCard(_filteredPromos[i]),
                      ),
                      childCount: _filteredPromos.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: ElevatedButton.icon(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded, color: Colors.black, size: 20),
        label: Text(
          'Novo Cupom',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryContainer,
          foregroundColor: Colors.black,
          minimumSize: const Size(100, 48),
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
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
            Icons.local_offer_rounded,
            color: AppTheme.primaryContainer,
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
                    'Promoções & Cupons',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE5E2E1),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'CAMPANHAS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryContainer,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Gestão de descontos e incentivos de corridas na plataforma',
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

  Widget _buildKpiSection(int active, int totalUses, int percentage) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  _kpiCard(
                    title: 'TOTAL DE CUPONS',
                    value: '${_promos.length}',
                    icon: Icons.confirmation_number_rounded,
                    color: AppTheme.primaryContainer,
                    subtitle: 'Criados no sistema',
                  ),
                  const SizedBox(width: 12),
                  _kpiCard(
                    title: 'CUPONS ATIVOS',
                    value: '$active',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF4CAF88),
                    subtitle: 'Em circulação',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _kpiCard(
                    title: 'TOTAL DE RESGATES',
                    value: '$totalUses',
                    icon: Icons.people_rounded,
                    color: const Color(0xFF5AB0FF),
                    subtitle: 'Usos por passageiros',
                  ),
                  const SizedBox(width: 12),
                  _kpiCard(
                    title: 'TIPO PERCENTUAL',
                    value: '$percentage',
                    icon: Icons.percent_rounded,
                    color: const Color(0xFFF5C842),
                    subtitle: 'Descontos percentuais',
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            _kpiCard(
              title: 'TOTAL DE CUPONS',
              value: '${_promos.length}',
              icon: Icons.confirmation_number_rounded,
              color: AppTheme.primaryContainer,
              subtitle: 'Criados no sistema',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'CUPONS ATIVOS',
              value: '$active',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF4CAF88),
              subtitle: 'Em circulação',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'TOTAL DE RESGATES',
              value: '$totalUses',
              icon: Icons.people_rounded,
              color: const Color(0xFF5AB0FF),
              subtitle: 'Usos por passageiros',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'TIPO PERCENTUAL',
              value: '$percentage',
              icon: Icons.percent_rounded,
              color: const Color(0xFFF5C842),
              subtitle: 'Descontos percentuais',
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
                hintText: 'Pesquisar código do cupom (ex: KUPON20)...',
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
                DropdownMenuItem(value: 'all', child: Text('Todos os Cupons')),
                DropdownMenuItem(value: 'active', child: Text('Apenas Ativos')),
                DropdownMenuItem(value: 'inactive', child: Text('Inativos')),
                DropdownMenuItem(value: 'percentage', child: Text('Tipo: %')),
                DropdownMenuItem(
                  value: 'fixed',
                  child: Text('Tipo: Fixo (Kz)'),
                ),
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

  Widget _buildPromoCard(Map<String, dynamic> promo) {
    final code = promo['code'] as String? ?? '–';
    final name = promo['name'] as String? ?? '';
    final description = promo['description'] as String? ?? '';
    final type = promo['discount_type'] as String? ?? 'percentage';
    final value = promo['discount_value'];
    final maxUses = promo['max_uses'] as int?;
    final maxPerUser = promo['max_uses_per_user'] as int?;
    final uses = promo['current_uses'] as int? ?? 0;
    final isActive = promo['is_active'] as bool? ?? false;
    final endDate = promo['end_date'];
    final minFare = promo['min_fare'];

    final discountText = type == 'percentage' ? '$value% OFF' : '$value Kz OFF';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.primaryContainer.withValues(alpha: 0.3)
              : AppTheme.outlineVariant.withValues(alpha: 0.25),
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: AppTheme.primaryContainer.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_offer_rounded,
                      color: AppTheme.primaryContainer,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      code,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE5E2E1),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF88).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  discountText,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4CAF88),
                  ),
                ),
              ),
              const Spacer(),
              _activeBadge(isActive),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                color: AppTheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (v) => _onMenuAction(v, promo),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: isActive ? 'deactivate' : 'activate',
                    child: Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                          size: 16,
                          color: const Color(0xFFE2BFB0),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isActive ? 'Pausar Cupom' : 'Ativar Cupom',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: const Color(0xFFE5E2E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Color(0xFFE2BFB0),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Editar Cupom',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: const Color(0xFFE5E2E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Color(0xFFCF6679),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Excluir',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: const Color(0xFFCF6679),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFFE2BFB0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (name.isNotEmpty) ...[
            Text(
              name,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE5E2E1),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12.5,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.65),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              _infoChip(
                Icons.people_outline_rounded,
                maxUses != null
                    ? '$uses de $maxUses usos'
                    : '$uses usos ilimitados',
              ),
              if (maxPerUser != null) ...[
                const SizedBox(width: 14),
                _infoChip(
                  Icons.person_outline_rounded,
                  'Máx $maxPerUser por utilizador',
                ),
              ],
              if (minFare != null) ...[
                const SizedBox(width: 14),
                _infoChip(Icons.monetization_on_outlined, 'Mínimo $minFare Kz'),
              ],
              if (endDate != null) ...[
                const SizedBox(width: 14),
                _infoChip(
                  Icons.schedule_outlined,
                  'Expira ${_fmtDate(endDate)}',
                ),
              ],
            ],
          ),
          if (maxUses != null) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PROGRESSO DE USO',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${((uses / maxUses) * 100).toInt()}%',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (uses / maxUses).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: AppTheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      (uses >= maxUses)
                          ? const Color(0xFFCF6679)
                          : AppTheme.primaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _activeBadge(bool active) {
    final color = active ? const Color(0xFF4CAF88) : const Color(0xFF9E9E9E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'Ativo' : 'Inativo',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11.5,
            color: const Color(0xFFE2BFB0).withValues(alpha: 0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                size: 40,
                color: Color(0xFFE2BFB0),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Nenhum cupom corresponde à pesquisa "$_searchQuery".'
                  : 'Nenhum cupom ou promoção criada.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openForm(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryContainer,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Criar Primeiro Cupom',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMenuAction(String action, Map<String, dynamic> promo) async {
    switch (action) {
      case 'activate':
      case 'deactivate':
        try {
          await _db
              .from('promotions')
              .update({'is_active': action == 'activate'})
              .eq('id', promo['id']);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  action == 'activate' ? 'Cupom ativado.' : 'Cupom pausado.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          _load();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao atualizar cupom: $e'),
                backgroundColor: const Color(0xFFCF6679),
              ),
            );
          }
        }
        break;
      case 'edit':
        _openForm(context, promo: promo);
        break;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Excluir promoção?',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: const Color(0xFFE5E2E1),
              ),
            ),
            content: Text(
              'Deseja excluir o cupom "${promo['code']}"? Esta ação não pode ser desfeita.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13.5,
                color: const Color(0xFFE2BFB0),
              ),
            ),
            actions: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE2BFB0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFCF6679),
                      minimumSize: const Size(64, 40),
                    ),
                    child: Text(
                      'Excluir',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (ok == true) {
          try {
            await _db.from('promotions').delete().eq('id', promo['id']);
            _load();
          } catch (e) {
            final msg = e.toString();
            final blocked =
                msg.contains('foreign key') ||
                msg.contains('23503') ||
                msg.contains('FOREIGN KEY');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    blocked
                        ? 'Este cupom já foi utilizado e não pode ser excluído. '
                              'Em vez disso, pode pausá-lo.'
                        : 'Erro ao excluir cupom: $e',
                  ),
                  backgroundColor: const Color(0xFFCF6679),
                ),
              );
            }
          }
        }
        break;
    }
  }

  Future<void> _openForm(
    BuildContext ctx, {
    Map<String, dynamic>? promo,
  }) async {
    final saved = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: _PromoFormDialog(
          promo: promo,
          onSave: (data) async {
            if (promo == null) {
              await _db.from('promotions').insert(data);
            } else {
              await _db.from('promotions').update(data).eq('id', promo['id']);
            }
            _load();
          },
        ),
      ),
    );
    if (saved == true && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            promo == null
                ? 'Cupom criado com sucesso.'
                : 'Cupom atualizado com sucesso.',
          ),
          backgroundColor: const Color(0xFF4CAF88),
        ),
      );
    }
    _load();
  }

  String _fmtDate(dynamic v) {
    if (v is! String || v.isEmpty) return '–';
    final d = DateTime.tryParse(v);
    if (d == null) return '–';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _PromoFormDialog extends StatefulWidget {
  final Map<String, dynamic>? promo;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _PromoFormDialog({this.promo, required this.onSave});

  @override
  State<_PromoFormDialog> createState() => _PromoFormDialogState();
}

class _PromoFormDialogState extends State<_PromoFormDialog> {
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _maxDiscountCtrl = TextEditingController();
  final _maxUsesCtrl = TextEditingController();
  final _maxPerUserCtrl = TextEditingController();
  final _minFareCtrl = TextEditingController();
  String _type = 'percentage';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;
  bool get _editing => widget.promo != null;

  @override
  void initState() {
    super.initState();
    if (widget.promo != null) {
      final p = widget.promo!;
      _nameCtrl.text = p['name'] ?? '';
      _descriptionCtrl.text = p['description'] ?? '';
      _codeCtrl.text = p['code'] ?? '';
      _valueCtrl.text = '${p['discount_value'] ?? ''}';
      _maxDiscountCtrl.text = '${p['max_discount'] ?? ''}';
      _maxUsesCtrl.text = '${p['max_uses'] ?? ''}';
      _maxPerUserCtrl.text = '${p['max_uses_per_user'] ?? ''}';
      _minFareCtrl.text = '${p['min_fare'] ?? ''}';
      _type = p['discount_type'] ?? 'percentage';
      _startDate = _parseDate(p['start_date']);
      _endDate = _parseDate(p['end_date']);
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v)?.toLocal();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _maxUsesCtrl.dispose();
    _maxPerUserCtrl.dispose();
    _minFareCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final value = int.tryParse(_valueCtrl.text.trim());
    if (name.isEmpty || code.isEmpty || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha o nome, o código e um valor de desconto válido.',
          ),
          backgroundColor: Color(0xFFCF6679),
        ),
      );
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Defina a data de início e de fim da validade.'),
          backgroundColor: Color(0xFFCF6679),
        ),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data de fim deve ser posterior à de início.'),
          backgroundColor: Color(0xFFCF6679),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave({
        'name': name,
        'code': code.toUpperCase(),
        'discount_type': _type,
        'discount_value': value,
        if (_maxDiscountCtrl.text.trim().isNotEmpty)
          'max_discount': int.tryParse(_maxDiscountCtrl.text.trim()),
        if (_maxUsesCtrl.text.trim().isNotEmpty)
          'max_uses': int.tryParse(_maxUsesCtrl.text.trim()),
        if (_maxPerUserCtrl.text.trim().isNotEmpty)
          'max_uses_per_user': int.tryParse(_maxPerUserCtrl.text.trim()),
        if (_minFareCtrl.text.trim().isNotEmpty)
          'min_fare': int.tryParse(_minFareCtrl.text.trim()),
        if (_descriptionCtrl.text.trim().isNotEmpty)
          'description': _descriptionCtrl.text.trim(),
        'start_date': _startDate!.toUtc().toIso8601String(),
        'end_date': DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        ).toUtc().toIso8601String(),
        if (!_editing) 'is_active': true,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final msg = e.toString();
        final friendly =
            msg.contains('duplicate') ||
                msg.contains('already exists') ||
                msg.contains('23505')
            ? 'Já existe um cupom com este código.'
            : 'Erro ao salvar cupom: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendly),
            backgroundColor: const Color(0xFFCF6679),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.local_offer_outlined,
                  color: AppTheme.primaryContainer,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.promo == null
                        ? 'Novo Cupom de Desconto'
                        : 'Editar Cupom',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE5E2E1),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  tooltip: 'Fechar',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFFE2BFB0),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOME DA PROMOÇÃO',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameCtrl,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: const Color(0xFFE5E2E1),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ex.: Boas-vindas, Festa Junina...',
                      hintStyle: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.35),
                      ),
                      fillColor: AppTheme.surfaceContainerLowest,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryContainer,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionCtrl,
                    maxLines: 2,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: const Color(0xFFE5E2E1),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Descrição (opcional)',
                      hintStyle: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.35),
                      ),
                      fillColor: AppTheme.surfaceContainerLowest,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryContainer,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'CÓDIGO DO CUPOM',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE5E2E1),
                    ),
                    decoration: InputDecoration(
                      hintText: 'EX: KUPON20, BEMVINDO',
                      hintStyle: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.35),
                      ),
                      fillColor: AppTheme.surfaceContainerLowest,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryContainer,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TIPO DE DESCONTO',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _typeBtn(
                        'percentage',
                        'Percentual (%)',
                        Icons.percent_rounded,
                      ),
                      const SizedBox(width: 10),
                      _typeBtn(
                        'fixed',
                        'Valor Fixo (Kz)',
                        Icons.monetization_on_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'VALOR DO DESCONTO',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _valueCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE5E2E1),
                    ),
                    decoration: InputDecoration(
                      hintText: _type == 'percentage'
                          ? 'Ex: 20 (para 20%)'
                          : 'Ex: 500 (para 500 Kz)',
                      hintStyle: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.35),
                      ),
                      suffixText: _type == 'percentage' ? '%' : 'Kz',
                      suffixStyle: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryContainer,
                      ),
                      fillColor: AppTheme.surfaceContainerLowest,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryContainer,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (_type == 'percentage') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _maxDiscountCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: const Color(0xFFE5E2E1),
                      ),
                      decoration: InputDecoration(
                        labelText: 'DESCONTO MÁXIMO (Kz)',
                        labelStyle: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                        ),
                        hintText: 'Opcional — teto do desconto',
                        hintStyle: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: const Color(
                            0xFFE2BFB0,
                          ).withValues(alpha: 0.35),
                        ),
                        fillColor: AppTheme.surfaceContainerLowest,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF2A2A2A),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF2A2A2A),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryContainer,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LIMITE DE USOS',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: const Color(
                                  0xFFE2BFB0,
                                ).withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _maxUsesCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                color: const Color(0xFFE5E2E1),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ilimitado',
                                hintStyle: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  color: const Color(
                                    0xFFE2BFB0,
                                  ).withValues(alpha: 0.35),
                                ),
                                fillColor: AppTheme.surfaceContainerLowest,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2A2A2A),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2A2A2A),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryContainer,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TARIFA MÍNIMA (Kz)',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: const Color(
                                  0xFFE2BFB0,
                                ).withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _minFareCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                color: const Color(0xFFE5E2E1),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Sem mínimo',
                                hintStyle: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  color: const Color(
                                    0xFFE2BFB0,
                                  ).withValues(alpha: 0.35),
                                ),
                                fillColor: AppTheme.surfaceContainerLowest,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2A2A2A),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2A2A2A),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryContainer,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField(
                          label: 'INÍCIO DA VALIDADE',
                          date: _startDate,
                          icon: Icons.event_available_rounded,
                          onTap: () => _pickDate(setStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField(
                          label: 'FIM DA VALIDADE',
                          date: _endDate,
                          icon: Icons.event_busy_rounded,
                          onTap: () => _pickDate(setStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LIMITE POR UTILIZADOR',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: const Color(
                                  0xFFE2BFB0,
                                ).withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _maxPerUserCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                color: const Color(0xFFE5E2E1),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ilimitado',
                                hintStyle: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  color: const Color(
                                    0xFFE2BFB0,
                                  ).withValues(alpha: 0.35),
                                ),
                                fillColor: AppTheme.surfaceContainerLowest,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2A2A2A),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2A2A2A),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryContainer,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE2BFB0),
                      side: const BorderSide(color: Color(0xFF2A2A2A)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryContainer,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            widget.promo == null
                                ? 'Criar Cupom'
                                : 'Salvar Alterações',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool setStart}) async {
    final now = DateTime.now();
    final initial = (setStart ? _startDate : _endDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: AppTheme.primaryContainer),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (setStart) {
          _startDate = DateTime(picked.year, picked.month, picked.day);
        } else {
          _endDate = DateTime(picked.year, picked.month, picked.day);
        }
      });
    }
  }

  Widget _dateField({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date == null ? 'Selecionar' : _fmtDateLong(date),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: date == null
                          ? const Color(0xFFE2BFB0)
                          : const Color(0xFFE5E2E1),
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

  String _fmtDateLong(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  Widget _typeBtn(String value, String label, IconData icon) {
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryContainer.withValues(alpha: 0.15)
                : AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryContainer
                  : const Color(0xFF2A2A2A),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? AppTheme.primaryContainer
                    : const Color(0xFFE2BFB0),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected
                      ? AppTheme.primaryContainer
                      : const Color(0xFFE2BFB0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
