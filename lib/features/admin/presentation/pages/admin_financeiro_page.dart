import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/payment_requests_section.dart';

class AdminFinanceiroPage extends StatefulWidget {
  const AdminFinanceiroPage({super.key});

  @override
  State<AdminFinanceiroPage> createState() => _AdminFinanceiroPageState();
}

class _AdminFinanceiroPageState extends State<AdminFinanceiroPage>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  late final TabController _tabCtrl;

  bool _loading = true;
  String _searchQuery = '';
  String _selectedStatusFilter =
      'all'; // 'all', 'completed', 'pending', 'failed'

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _pendingTopups = [];
  List<Map<String, dynamic>> _pendingSubs = [];

  int _totalRevenue = 0;
  int _pendingWithdrawsCount = 0;
  int _pendingWithdrawsAmount = 0;
  int _pendingTopupsAmount = 0;
  int _pendingSubsAmount = 0;
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final txFuture = _db
          .from('credit_transactions')
          .select('*, users!inner(id, name, photo_url, phone)')
          .order('created_at', ascending: false)
          .limit(100);
      final topupsFuture = _db.rpc('admin_get_pending_topups');
      final subsFuture = _db.rpc('admin_get_pending_subscriptions');

      final list = List<Map<String, dynamic>>.from(await txFuture);
      final topups = List<Map<String, dynamic>>.from(
        (await topupsFuture) as List? ?? const [],
      );
      final subs = List<Map<String, dynamic>>.from(
        (await subsFuture) as List? ?? const [],
      );

      if (mounted) {
        int revenue = 0;
        int pendingWithCount = 0;
        int pendingWithAmount = 0;

        for (final t in list) {
          final amount = (t['amount'] as num?)?.toInt() ?? 0;
          final type = t['type'] as String? ?? '';
          final status = t['status'] as String? ?? '';

          if (type == 'ride_payment') revenue += amount;
          if (type == 'withdraw' && status == 'pending') {
            pendingWithCount++;
            pendingWithAmount += amount.abs();
          }
        }

        int topupsAmount = 0;
        for (final t in topups) {
          topupsAmount += (t['amount'] as num?)?.toInt() ?? 0;
        }

        int subsAmount = 0;
        for (final s in subs) {
          subsAmount += (s['price'] as num?)?.toInt() ?? 0;
        }

        setState(() {
          _transactions = list;
          _pendingTopups = topups;
          _pendingSubs = subs;
          _totalRevenue = revenue;
          _pendingWithdrawsCount = pendingWithCount;
          _pendingWithdrawsAmount = pendingWithAmount;
          _pendingTopupsAmount = topupsAmount;
          _pendingSubsAmount = subsAmount;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderBar(),
                    const SizedBox(height: 18),
                    _buildKpiSection(),
                    const SizedBox(height: 18),
                    _buildSearchBarAndFilter(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  indicatorColor: AppTheme.primaryContainer,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: AppTheme.outlineVariant.withValues(alpha: 0.3),
                  labelColor: AppTheme.primaryContainer,
                  unselectedLabelColor: const Color(
                    0xFFE2BFB0,
                  ).withValues(alpha: 0.6),
                  labelStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    Tab(
                      child: _tabLabel(
                        icon: Icons.receipt_long_rounded,
                        text: 'Todas',
                        count: _transactions.length,
                        badgeColor: AppTheme.primaryContainer,
                      ),
                    ),
                    Tab(
                      child: _tabLabel(
                        icon: Icons.arrow_circle_up_rounded,
                        text: 'Saques',
                        count: _pendingWithdrawsCount,
                        badgeColor: const Color(0xFFF5C842),
                        showCountWhenZero: false,
                      ),
                    ),
                    Tab(
                      child: _tabLabel(
                        icon: Icons.directions_car_rounded,
                        text: 'Corridas',
                        count: _transactions
                            .where((t) => t['type'] == 'ride_payment')
                            .length,
                        badgeColor: const Color(0xFF4CAF88),
                      ),
                    ),
                    Tab(
                      child: _tabLabel(
                        icon: Icons.currency_exchange_rounded,
                        text: 'Top-ups',
                        count: _pendingTopups.length,
                        badgeColor: const Color(0xFFFF6B00),
                        showCountWhenZero: false,
                      ),
                    ),
                    Tab(
                      child: _tabLabel(
                        icon: Icons.workspace_premium_rounded,
                        text: 'Assinaturas',
                        count: _pendingSubs.length,
                        badgeColor: const Color(0xFF4CAF88),
                        showCountWhenZero: false,
                      ),
                    ),
                    Tab(
                      child: _tabLabel(
                        icon: Icons.account_balance_wallet_rounded,
                        text: 'Pagamentos',
                        count: 0,
                        badgeColor: const Color(0xFFB08A3F),
                        showCountWhenZero: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: _loading
              ? const Center(child: KuponLoader())
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildList(),
                    _buildList(filter: (t) => t['type'] == 'withdraw'),
                    _buildList(filter: (t) => t['type'] == 'ride_payment'),
                    _buildPendingTopups(),
                    _buildPendingSubs(),
                    PaymentRequestsSection(
                      adminId: _db.auth.currentUser?.id ?? '',
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tabLabel({
    required IconData icon,
    required String text,
    required int count,
    required Color badgeColor,
    bool showCountWhenZero = true,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(text),
        if (count > 0 || showCountWhenZero) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: count > 0 ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: badgeColor.withValues(alpha: count > 0 ? 0.4 : 0.15),
              ),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: count > 0
                    ? badgeColor
                    : const Color(0xFFE2BFB0).withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
            Icons.account_balance_wallet_rounded,
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
                    'Tarifas e Finanças',
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
                      'AO VIVO',
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
                'Liquidações de corridas, saques, top-ups manuais e subscrições',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Atualizar dados',
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

  Widget _buildKpiSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  _kpiCard(
                    title: 'RECEITA DE CORRIDAS',
                    value: '${_fmt(_totalRevenue)} Kup',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFFFF6B00),
                    subtitle: 'Volume gerado por passageiros',
                  ),
                  const SizedBox(width: 12),
                  _kpiCard(
                    title: 'SAQUES PENDENTES',
                    value: '$_pendingWithdrawsCount',
                    icon: Icons.hourglass_top_rounded,
                    color: const Color(0xFFF5C842),
                    subtitle: '${_fmt(_pendingWithdrawsAmount)} Kup aguardando',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _kpiCard(
                    title: 'RECARGAS PENDENTES',
                    value: '${_pendingTopups.length}',
                    icon: Icons.currency_exchange_rounded,
                    color: const Color(0xFF4CAF88),
                    subtitle: '${_fmt(_pendingTopupsAmount)} Kup a confirmar',
                  ),
                  const SizedBox(width: 12),
                  _kpiCard(
                    title: 'ASSINATURAS PENDENTES',
                    value: '${_pendingSubs.length}',
                    icon: Icons.workspace_premium_rounded,
                    color: const Color(0xFF5AB0FF),
                    subtitle: '${_fmt(_pendingSubsAmount)} Kup em pedidos',
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            _kpiCard(
              title: 'RECEITA DE CORRIDAS',
              value: '${_fmt(_totalRevenue)} Kup',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFFFF6B00),
              subtitle: 'Volume bruto de tarifas',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'SAQUES PENDENTES',
              value: '$_pendingWithdrawsCount',
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFF5C842),
              subtitle: '${_fmt(_pendingWithdrawsAmount)} Kup a liquidar',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'TOP-UPS PENDENTES',
              value: '${_pendingTopups.length}',
              icon: Icons.currency_exchange_rounded,
              color: const Color(0xFF4CAF88),
              subtitle: '${_fmt(_pendingTopupsAmount)} Kup a confirmar',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'ASSINATURAS',
              value: '${_pendingSubs.length}',
              icon: Icons.workspace_premium_rounded,
              color: const Color(0xFF5AB0FF),
              subtitle: '${_fmt(_pendingSubsAmount)} Kup em validação',
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
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
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
                letterSpacing: -0.3,
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
                hintText: 'Pesquisar por usuário, telefone, ID ou tipo...',
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
              value: _selectedStatusFilter,
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
                DropdownMenuItem(value: 'completed', child: Text('Concluídos')),
                DropdownMenuItem(value: 'pending', child: Text('Pendentes')),
                DropdownMenuItem(
                  value: 'failed',
                  child: Text('Falhados/Cancelados'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedStatusFilter = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList({bool Function(Map<String, dynamic>)? filter}) {
    var items = filter == null
        ? _transactions
        : _transactions.where(filter).toList();

    if (_searchQuery.isNotEmpty) {
      items = items.where((t) {
        final user = t['users'] as Map<String, dynamic>? ?? {};
        final name = (user['name'] as String? ?? '').toLowerCase();
        final phone = (user['phone'] as String? ?? '').toLowerCase();
        final type = (t['type'] as String? ?? '').toLowerCase();
        final id = (t['id'] as String? ?? '').toLowerCase();
        final desc = (t['description'] as String? ?? '').toLowerCase();

        return name.contains(_searchQuery) ||
            phone.contains(_searchQuery) ||
            type.contains(_searchQuery) ||
            id.contains(_searchQuery) ||
            desc.contains(_searchQuery);
      }).toList();
    }

    if (_selectedStatusFilter != 'all') {
      items = items.where((t) {
        final status = (t['status'] as String? ?? 'completed').toLowerCase();
        if (_selectedStatusFilter == 'completed') return status == 'completed';
        if (_selectedStatusFilter == 'pending') return status == 'pending';
        if (_selectedStatusFilter == 'failed')
          return status == 'failed' || status == 'cancelled';
        return true;
      }).toList();
    }

    if (items.isEmpty) {
      return _emptyState(
        _searchQuery.isNotEmpty
            ? 'Nenhuma transação corresponde à pesquisa "$_searchQuery".'
            : 'Nenhuma transação registada nesta categoria.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryContainer,
      backgroundColor: AppTheme.surfaceContainerLow,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildTxTile(items[i]),
      ),
    );
  }

  Widget _buildTxTile(Map<String, dynamic> tx) {
    final user = tx['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Usuário';
    final photo = user['photo_url'] as String?;
    final phone = user['phone'] as String?;
    final type = tx['type'] as String? ?? '–';
    final amount = (tx['amount'] as num?)?.toInt() ?? 0;
    final status = tx['status'] as String? ?? 'completed';
    final date = _fmtDate(tx['created_at']);
    final desc = tx['description'] as String?;

    final isDebit = type == 'withdraw' || type == 'ride_payment';
    final amountColor = isDebit
        ? const Color(0xFFCF6679)
        : const Color(0xFF4CAF88);
    final amountPrefix = isDebit ? '-' : '+';
    final isPendingWithdraw = type == 'withdraw' && status == 'pending';

    return InkWell(
      onTap: () => _showTransactionDetailModal(tx),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPendingWithdraw
                ? const Color(0xFFF5C842).withValues(alpha: 0.4)
                : AppTheme.outlineVariant.withValues(alpha: 0.3),
            width: isPendingWithdraw ? 1.2 : 1,
          ),
          boxShadow: [
            if (isPendingWithdraw)
              BoxShadow(
                color: const Color(0xFFF5C842).withValues(alpha: 0.06),
                blurRadius: 10,
              ),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(photo, name),
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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE5E2E1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _typeChip(type),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _statusDot(status),
                      const SizedBox(width: 6),
                      Text(
                        _statusText(status),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(status),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  $date',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                        ),
                      ),
                      if (phone != null && phone.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•  $phone',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: const Color(
                              0xFFE2BFB0,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountPrefix ${_fmt(amount.abs())} Kup',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
                if (isPendingWithdraw) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _confirmApproveWithdraw(
                          tx['id'] as String,
                          name,
                          amount.abs(),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF4CAF88,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(
                                0xFF4CAF88,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Color(0xFF4CAF88),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Aprovar',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  color: const Color(0xFF4CAF88),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                  ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photo, String name) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryContainer.withValues(alpha: 0.3),
            AppTheme.surfaceContainerHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ClipOval(
        child: photo != null && photo.isNotEmpty
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _avatarFallback(name),
              )
            : _avatarFallback(name),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryContainer,
        ),
      ),
    );
  }

  Widget _typeChip(String type) {
    final config = _getTypeConfig(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 10, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  _TypeConfig _getTypeConfig(String type) {
    switch (type) {
      case 'withdraw':
        return _TypeConfig(
          'Saque',
          const Color(0xFFCF6679),
          Icons.arrow_circle_up_rounded,
        );
      case 'ride_payment':
        return _TypeConfig(
          'Corrida',
          const Color(0xFFFF6B00),
          Icons.directions_car_rounded,
        );
      case 'topup':
        return _TypeConfig(
          'Recarga',
          const Color(0xFF4CAF88),
          Icons.add_circle_outline_rounded,
        );
      case 'transfer':
        return _TypeConfig(
          'Transferência',
          const Color(0xFF5AB0FF),
          Icons.swap_horiz_rounded,
        );
      case 'subscription':
        return _TypeConfig(
          'Assinatura',
          const Color(0xFFE2BFB0),
          Icons.card_membership_rounded,
        );
      case 'bonus':
        return _TypeConfig(
          'Bônus',
          const Color(0xFFF5C842),
          Icons.stars_rounded,
        );
      default:
        return _TypeConfig(
          type,
          const Color(0xFF9E9E9E),
          Icons.receipt_rounded,
        );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF4CAF88);
      case 'pending':
        return const Color(0xFFF5C842);
      case 'failed':
      case 'cancelled':
        return const Color(0xFFCF6679);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'completed':
        return 'Concluído';
      case 'pending':
        return 'Pendente';
      case 'failed':
        return 'Falhou';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  Widget _statusDot(String status) {
    final color = _statusColor(status);
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4),
        ],
      ),
    );
  }

  Future<void> _confirmApproveWithdraw(
    String txId,
    String userName,
    int amount,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Aprovar Saque',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            color: const Color(0xFFE5E2E1),
          ),
        ),
        content: Text(
          'Deseja confirmar a liquidação de ${_fmt(amount)} Kup para $userName?',
          style: GoogleFonts.spaceGrotesk(color: const Color(0xFFE2BFB0)),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.spaceGrotesk(color: const Color(0xFFE2BFB0)),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF88),
                  minimumSize: const Size(64, 40),
                ),
                child: Text(
                  'Confirmar Saque',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _approveWithdraw(txId);
    }
  }

  Future<void> _approveWithdraw(String txId) async {
    try {
      await _db
          .from('credit_transactions')
          .update({'status': 'completed'})
          .eq('id', txId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saque aprovado com sucesso!'),
            backgroundColor: Color(0xFF4CAF88),
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aprovar saque: $e'),
            backgroundColor: const Color(0xFFCF6679),
          ),
        );
      }
    }
  }

  Future<void> _runAction(
    String key,
    Future<void> Function() action,
    String successMsg,
  ) async {
    if (_busyKey != null) return;
    setState(() => _busyKey = key);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: const Color(0xFF4CAF88),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: const Color(0xFFCF6679),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Widget _buildPendingTopups() {
    if (_pendingTopups.isEmpty) {
      return _emptyState('Sem recargas/top-ups pendentes de validação.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryContainer,
      backgroundColor: AppTheme.surfaceContainerLow,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        itemCount: _pendingTopups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final t = _pendingTopups[i];
          final id = t['id'];
          final busy = _busyKey == id;
          final amount = (t['amount'] as num?)?.toInt() ?? 0;
          final name = t['name'] ?? 'Usuário';

          return _pendingCard(
            leading: Icons.currency_exchange_rounded,
            color: const Color(0xFFFF6B00),
            title: '$name • ${_fmt(amount)} Kup',
            subtitle:
                'Método: ${t['method'] ?? 'mobile_money'}${t['reference'] != null ? ' • Ref: ${t['reference']}' : ''}\nTel: ${t['phone'] ?? '—'} • Solicitado ${_fmtDate(t['created_at'])}',
            confirmTooltip: 'Confirmar recarga',
            rejectTooltip: 'Rejeitar recarga',
            confirmLabel: 'Aprovar Recarga',
            showReject: true,
            confirmEnabled: !busy,
            rejectEnabled: !busy,
            onConfirm: () => _runAction(
              id,
              () => _db.rpc('confirm_credit_topup', params: {'p_topup_id': id}),
              'Recarga de ${_fmt(amount)} Kup confirmada e creditada para $name.',
            ),
            onReject: () => _runAction(
              id,
              () => _db.rpc('reject_credit_topup', params: {'p_topup_id': id}),
              'Recarga rejeitada.',
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingSubs() {
    if (_pendingSubs.isEmpty) {
      return _emptyState('Sem assinaturas pendentes de validação.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryContainer,
      backgroundColor: AppTheme.surfaceContainerLow,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        itemCount: _pendingSubs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final s = _pendingSubs[i];
          final id = s['id'];
          final busy = _busyKey == id;
          final price = (s['price'] as num?)?.toInt() ?? 0;
          final planName = s['plan_name'] ?? 'Plano';
          final name = s['name'] ?? 'Usuário';

          return _pendingCard(
            leading: Icons.workspace_premium_rounded,
            color: const Color(0xFF4CAF88),
            title: '$planName • ${_fmt(price)} Kup',
            subtitle:
                'Usuário: $name • Tel: ${s['phone'] ?? '—'}\nPedido realizado em ${_fmtDate(s['created_at'])} (Aguardando ativação)',
            confirmTooltip: 'Confirmar e ativar plano',
            rejectTooltip: 'Rejeitar assinatura',
            confirmLabel: 'Ativar Plano',
            showReject: true,
            confirmEnabled: !busy,
            rejectEnabled: !busy,
            onConfirm: () => _runAction(
              id,
              () => _db.rpc('confirm_subscription', params: {'p_sub_id': id}),
              'Assinatura do $planName ativada com sucesso para $name.',
            ),
            onReject: () => _runAction(
              id,
              () => _db.rpc('reject_subscription', params: {'p_sub_id': id}),
              'Assinatura rejeitada.',
            ),
          );
        },
      ),
    );
  }

  Widget _pendingCard({
    required IconData leading,
    required Color color,
    required String title,
    required String subtitle,
    required String confirmTooltip,
    String? rejectTooltip,
    required String confirmLabel,
    bool showReject = true,
    required bool confirmEnabled,
    bool rejectEnabled = false,
    required VoidCallback onConfirm,
    VoidCallback? onReject,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(leading, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE5E2E1),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5,
                        height: 1.4,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (showReject) ...[
                OutlinedButton.icon(
                  onPressed: rejectEnabled ? onReject : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFCF6679),
                    side: BorderSide(
                      color: const Color(0xFFCF6679).withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text(
                    'Rejeitar',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              FilledButton.icon(
                onPressed: confirmEnabled ? onConfirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF88),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: confirmEnabled
                    ? const Icon(Icons.check_circle_rounded, size: 16)
                    : const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      ),
                label: Text(
                  confirmLabel,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTransactionDetailModal(Map<String, dynamic> tx) {
    final user = tx['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Usuário';
    final photo = user['photo_url'] as String?;
    final phone = user['phone'] as String? ?? '–';
    final type = tx['type'] as String? ?? '–';
    final amount = (tx['amount'] as num?)?.toInt() ?? 0;
    final status = tx['status'] as String? ?? 'completed';
    final date = _fmtDate(tx['created_at']);
    final desc = tx['description'] as String? ?? '–';
    final id = tx['id'] as String? ?? '–';
    final balAfter = tx['balance_after'];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLow,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
            Row(
              children: [
                _buildAvatar(photo, name),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE5E2E1),
                        ),
                      ),
                      Text(
                        'Tel: $phone',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                _typeChip(type),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2A2A2A)),
            const SizedBox(height: 12),
            _detailRow('Valor', '${_fmt(amount.abs())} Kup', isHighlight: true),
            _detailRow('Status', _statusText(status)),
            _detailRow('Data / Hora', date),
            _detailRow('Descrição', desc),
            if (balAfter != null)
              _detailRow(
                'Saldo após operação',
                '${_fmt((balAfter as num).toInt())} Kup',
              ),
            _detailRow('ID da Transação', id),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.surfaceContainerHighest,
                  foregroundColor: const Color(0xFFE5E2E1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Fechar',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12.5,
              color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceGrotesk(
                fontSize: isHighlight ? 15 : 12.5,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                color: isHighlight
                    ? AppTheme.primaryContainer
                    : const Color(0xFFE5E2E1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
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
                Icons.receipt_long_outlined,
                size: 40,
                color: Color(0xFFE2BFB0),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13.5,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );

  String _fmtDate(dynamic v) {
    if (v is! String || v.isEmpty) return '–';
    final d = DateTime.tryParse(v);
    if (d == null) return '–';
    final local = d.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _TypeConfig {
  final String label;
  final Color color;
  final IconData icon;

  _TypeConfig(this.label, this.color, this.icon);
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppTheme.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
