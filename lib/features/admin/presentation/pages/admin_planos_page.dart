import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPlanosPage extends StatefulWidget {
  const AdminPlanosPage({super.key});

  @override
  State<AdminPlanosPage> createState() => _AdminPlanosPageState();
}

class _AdminPlanosPageState extends State<AdminPlanosPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _plans = [];

  String _searchQuery = '';
  String _statusFilter =
      'all'; // 'all', 'active', 'inactive', 'monthly', 'annual'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _db
          .from('subscription_plans')
          .select('*')
          .order('price', ascending: true);
      if (mounted) {
        setState(() {
          _plans = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredPlans {
    var list = _plans;
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) {
        final name = (p['name'] as String? ?? '').toLowerCase();
        final desc = (p['description'] as String? ?? '').toLowerCase();
        return name.contains(_searchQuery) || desc.contains(_searchQuery);
      }).toList();
    }

    if (_statusFilter == 'active') {
      list = list.where((p) => p['is_active'] == true).toList();
    } else if (_statusFilter == 'inactive') {
      list = list.where((p) => p['is_active'] != true).toList();
    } else if (_statusFilter == 'monthly') {
      list = list.where((p) => (p['period_days'] as int? ?? 30) <= 30).toList();
    } else if (_statusFilter == 'annual') {
      list = list.where((p) => (p['period_days'] as int? ?? 30) > 30).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _plans.where((p) => p['is_active'] == true).length;
    final totalQuota = _plans.fold<int>(
      0,
      (sum, p) => sum + ((p['trip_quota'] as num?)?.toInt() ?? 0),
    );
    final avgPrice = _plans.isNotEmpty
        ? (_plans.fold<int>(
                0,
                (sum, p) => sum + ((p['price'] as num?)?.toInt() ?? 0),
              ) ~/
              _plans.length)
        : 0;

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
                      _buildKpiSection(activeCount, totalQuota, avgPrice),
                      const SizedBox(height: 18),
                      _buildSearchBarAndFilter(),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(child: Center(child: KuponLoader()))
              else if (_filteredPlans.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildPlanCard(_filteredPlans[i]),
                      ),
                      childCount: _filteredPlans.length,
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
          'Novo Plano',
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
            Icons.card_membership_rounded,
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
                    'Planos de Assinatura',
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
                      color: const Color(0xFF5AB0FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PASSES KUPON+',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF5AB0FF),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Modelo "Pague uma vez, viaje sempre": gestão de cotas e tarifas',
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

  Widget _buildKpiSection(int active, int totalQuota, int avgPrice) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  _kpiCard(
                    title: 'TOTAL DE PLANOS',
                    value: '${_plans.length}',
                    icon: Icons.layers_rounded,
                    color: AppTheme.primaryContainer,
                    subtitle: 'Configurados no sistema',
                  ),
                  const SizedBox(width: 12),
                  _kpiCard(
                    title: 'PLANOS ATIVOS',
                    value: '$active',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF4CAF88),
                    subtitle: 'Disponíveis no app',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _kpiCard(
                    title: 'COTA ACUMULADA',
                    value: '$totalQuota',
                    icon: Icons.confirmation_number_rounded,
                    color: const Color(0xFF5AB0FF),
                    subtitle: 'Viagens em catálogo',
                  ),
                  const SizedBox(width: 12),
                  _kpiCard(
                    title: 'VALOR MÉDIO',
                    value: '${_fmt(avgPrice)} Kz',
                    icon: Icons.monetization_on_rounded,
                    color: const Color(0xFFF5C842),
                    subtitle: 'Preço médio mensal',
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            _kpiCard(
              title: 'TOTAL DE PLANOS',
              value: '${_plans.length}',
              icon: Icons.layers_rounded,
              color: AppTheme.primaryContainer,
              subtitle: 'Configurados no sistema',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'PLANOS ATIVOS',
              value: '$active',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF4CAF88),
              subtitle: 'Disponíveis no app',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'COTA ACUMULADA',
              value: '$totalQuota',
              icon: Icons.confirmation_number_rounded,
              color: const Color(0xFF5AB0FF),
              subtitle: 'Viagens em catálogo',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'VALOR MÉDIO',
              value: '${_fmt(avgPrice)} Kz',
              icon: Icons.monetization_on_rounded,
              color: const Color(0xFFF5C842),
              subtitle: 'Preço médio mensal',
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
                hintText: 'Pesquisar plano (ex: Básico, Premium, Black)...',
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
                DropdownMenuItem(value: 'all', child: Text('Todos os Planos')),
                DropdownMenuItem(value: 'active', child: Text('Apenas Ativos')),
                DropdownMenuItem(value: 'inactive', child: Text('Inativos')),
                DropdownMenuItem(
                  value: 'monthly',
                  child: Text('Planos Mensais (≤ 30d)'),
                ),
                DropdownMenuItem(
                  value: 'annual',
                  child: Text('Planos Anuais (> 30d)'),
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

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final name = plan['name'] as String? ?? '–';
    final price = (plan['price'] as num?)?.toInt() ?? 0;
    final credits = (plan['credits'] as num?)?.toInt() ?? 0;
    final tripQuota = (plan['trip_quota'] as num?)?.toInt() ?? 0;
    final period = plan['period_days'] as int? ?? 30;
    final isActive = plan['is_active'] as bool? ?? true;
    final description = plan['description'] as String?;

    final periodLabel = period == 30
        ? 'Mensal (30 dias)'
        : period == 365
        ? 'Anual (12 meses)'
        : '$period dias';

    return Container(
      padding: const EdgeInsets.all(20),
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
              blurRadius: 14,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryContainer.withValues(alpha: 0.25),
                      AppTheme.surfaceContainerHighest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryContainer.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
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
                          name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE5E2E1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _activeBadge(isActive),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      periodLabel,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppTheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (v) => _onMenu(v, plan),
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
                          isActive ? 'Desativar Plano' : 'Ativar Plano',
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
                          'Editar Plano',
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
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              description,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12.5,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.75),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _valuePill(
                'Preço',
                '${_fmt(price)} Kz',
                AppTheme.primaryContainer,
                Icons.monetization_on_rounded,
              ),
              const SizedBox(width: 10),
              _valuePill(
                'Cota de Viagens',
                tripQuota > 0 ? '$tripQuota viagens' : 'Sem cota',
                const Color(0xFF5AB0FF),
                Icons.directions_car_rounded,
              ),
              const SizedBox(width: 10),
              _valuePill(
                'Créditos Kup',
                '${_fmt(credits)} Kup',
                const Color(0xFF4CAF88),
                Icons.currency_exchange_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valuePill(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeBadge(bool active) {
    final color = active ? const Color(0xFF4CAF88) : const Color(0xFF9E9E9E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
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
          const SizedBox(width: 4),
          Text(
            active ? 'Ativo' : 'Inativo',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.card_membership_outlined,
                size: 40,
                color: Color(0xFFE2BFB0),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Nenhum plano corresponde à pesquisa "$_searchQuery".'
                  : 'Nenhum plano de assinatura configurado.',
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
                'Criar Primeiro Plano',
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

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFCF6679) : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onMenu(String action, Map<String, dynamic> plan) async {
    switch (action) {
      case 'activate':
      case 'deactivate':
        try {
          await _db
              .from('subscription_plans')
              .update({'is_active': action == 'activate'})
              .eq('id', plan['id']);
          if (!mounted) return;
          _showSnack(
            action == 'activate' ? 'Plano ativado.' : 'Plano desativado.',
          );
          _load();
        } catch (e) {
          _showSnack(
            'Erro ao atualizar plano: ${_errMsg(e)}',
            error: true,
          );
        }
        break;
      case 'edit':
        _openForm(context, plan: plan);
        break;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Excluir plano?',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: const Color(0xFFE5E2E1),
              ),
            ),
            content: Text(
              'Deseja excluir o plano "${plan['name']}"? Esta ação removerá a opção de novas assinaturas.',
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
                    onPressed: () => Navigator.pop(context, false),
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
                    onPressed: () => Navigator.pop(context, true),
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
        if (!mounted) return;
        if (ok == true) {
          try {
            await _db
                .from('subscription_plans')
                .delete()
                .eq('id', plan['id']);
            if (!mounted) return;
            _showSnack('Plano excluído.');
            _load();
          } catch (e) {
            _showSnack('Erro ao excluir plano: ${_errMsg(e)}', error: true);
          }
        }
        break;
    }
  }

  String _errMsg(Object e) {
    if (e is PostgrestException) {
      if (e.code == '23503') {
        return 'não é possível excluir: existem assinaturas ativas associadas.';
      }
      return e.message;
    }
    return '$e';
  }

  void _openForm(BuildContext ctx, {Map<String, dynamic>? plan}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PlanFormSheet(
        plan: plan,
        onSave: (data) async {
          if (plan == null) {
            await _db.from('subscription_plans').insert(data);
          } else {
            await _db
                .from('subscription_plans')
                .update(data)
                .eq('id', plan['id']);
          }
          _load();
        },
      ),
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
}

class _PlanFormSheet extends StatefulWidget {
  final Map<String, dynamic>? plan;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _PlanFormSheet({this.plan, required this.onSave});

  @override
  State<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends State<_PlanFormSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _creditsCtrl = TextEditingController();
  final _tripQuotaCtrl = TextEditingController();
  final _periodCtrl = TextEditingController(text: '30');
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.plan != null) {
      final p = widget.plan!;
      _nameCtrl.text = p['name'] ?? '';
      _priceCtrl.text = '${p['price'] ?? ''}';
      _creditsCtrl.text = '${p['credits'] ?? ''}';
      _tripQuotaCtrl.text = '${p['trip_quota'] ?? ''}';
      _periodCtrl.text = '${p['period_days'] ?? 30}';
      _descCtrl.text = p['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _creditsCtrl.dispose();
    _tripQuotaCtrl.dispose();
    _periodCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha o nome e o preço do plano.'),
          backgroundColor: Color(0xFFCF6679),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave({
        'name': _nameCtrl.text.trim(),
        'price': num.tryParse(_priceCtrl.text) ?? 0,
        'credits': num.tryParse(_creditsCtrl.text) ?? 0,
        if (_tripQuotaCtrl.text.isNotEmpty)
          'trip_quota': int.tryParse(_tripQuotaCtrl.text) ?? 0,
        'period_days': int.tryParse(_periodCtrl.text) ?? 30,
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
        'is_active': true,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar plano: $e'),
            backgroundColor: const Color(0xFFCF6679),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.plan == null ? 'Novo Plano de Assinatura' : 'Editar Plano',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE5E2E1),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'NOME DO PLANO',
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
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE5E2E1),
              ),
              decoration: InputDecoration(
                hintText: 'Ex: KupOn Básico, KupOn Black, Estudante',
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PREÇO (Kz)',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE5E2E1),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ex: 15000',
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
                        'COTA DE VIAGENS/MÊS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _tripQuotaCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE5E2E1),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ex: 10, 30, 60',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CRÉDITOS INCLUÍDOS (Kup)',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _creditsCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          color: const Color(0xFFE5E2E1),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ex: 15000',
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
                        'VIGÊNCIA (DIAS)',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _periodCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          color: const Color(0xFFE5E2E1),
                        ),
                        decoration: InputDecoration(
                          hintText: '30 para mensal, 365 para anual',
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
            Text(
              'DESCRIÇÃO / BENEFÍCIOS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: const Color(0xFFE5E2E1),
              ),
              decoration: InputDecoration(
                hintText:
                    'Ex: Cota de 30 viagens por mês, suporte prioritário e bônus',
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: Colors.black,
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
                        widget.plan == null
                            ? 'Criar Plano'
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
    );
  }
}
