import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSuportePage extends StatefulWidget {
  const AdminSuportePage({super.key});

  @override
  State<AdminSuportePage> createState() => _AdminSuportePageState();
}

class _AdminSuportePageState extends State<AdminSuportePage>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  late final TabController _tabCtrl;

  bool _loading = true;
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _openTicket;
  List<Map<String, dynamic>> _ticketReplies = [];
  bool _loadingReplies = false;

  String _searchQuery = '';
  String _selectedPriorityFilter = 'all';
  final _replyCtrl = TextEditingController();

  static bool _isOpenStatus(String? s) => s == 'open' || s == 'in_progress';
  static bool _isClosedStatus(String? s) => s == 'resolved' || s == 'closed';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _db
          .from('support_tickets')
          .select('*, users!inner(id, name, photo_url, phone)')
          .order('created_at', ascending: false)
          .limit(80);
      if (mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReplies(String ticketId) async {
    setState(() => _loadingReplies = true);
    try {
      final data = await _db
          .from('support_replies')
          .select('*, users!support_replies_sender_id_fkey(name, photo_url)')
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _ticketReplies = List<Map<String, dynamic>>.from(data as List);
          _loadingReplies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReplies = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _tickets;
    switch (_tabCtrl.index) {
      case 1:
        list = list.where((t) => _isOpenStatus(t['status'] as String?)).toList();
        break;
      case 2:
        list = list.where((t) => _isClosedStatus(t['status'] as String?)).toList();
        break;
      default:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((t) {
        final user = t['users'] as Map<String, dynamic>? ?? {};
        final name = (user['name'] as String? ?? '').toLowerCase();
        final phone = (user['phone'] as String? ?? '').toLowerCase();
        final subject = (t['subject'] as String? ?? '').toLowerCase();
        final description = (t['description'] as String? ?? '').toLowerCase();
        final id = (t['id'] as String? ?? '').toLowerCase();

        return name.contains(_searchQuery) ||
            phone.contains(_searchQuery) ||
            subject.contains(_searchQuery) ||
            description.contains(_searchQuery) ||
            id.contains(_searchQuery);
      }).toList();
    }

    if (_selectedPriorityFilter != 'all') {
      list = list.where((t) => t['priority'] == _selectedPriorityFilter).toList();
    }

    return list;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_openTicket != null) {
      return _buildTicketDetail(_openTicket!);
    }

    final openCount = _tickets.where((t) => _isOpenStatus(t['status'] as String?)).length;
    final closedCount = _tickets.where((t) => _isClosedStatus(t['status'] as String?)).length;
    final urgentCount = _tickets
        .where((t) => t['priority'] == 'urgent' && _isOpenStatus(t['status'] as String?))
        .length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderBar(),
                    const SizedBox(height: 18),
                    _buildKpiSection(openCount, urgentCount, closedCount),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  indicatorColor: AppTheme.primaryContainer,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: AppTheme.outlineVariant.withValues(alpha: 0.3),
                  labelColor: AppTheme.primaryContainer,
                  unselectedLabelColor: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
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
                        icon: Icons.all_inbox_rounded,
                        text: 'Todos',
                        count: _tickets.length,
                        badgeColor: AppTheme.primaryContainer,
                      ),
                    ),
                    Tab(
                      child: _tabLabel(
                        icon: Icons.mark_email_unread_rounded,
                        text: 'Abertos',
                        count: openCount,
                        badgeColor: const Color(0xFFF5C842),
                      ),
                    ),
                    Tab(
                      child: _tabLabel(
                        icon: Icons.task_alt_rounded,
                        text: 'Fechados',
                        count: closedCount,
                        badgeColor: const Color(0xFF4CAF88),
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
                  children: List.generate(3, (_) => _buildList()),
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
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(text),
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
              color: count > 0 ? badgeColor : const Color(0xFFE2BFB0).withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
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
            Icons.support_agent_rounded,
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
                    'Fila de Suporte',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE5E2E1),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF88).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'HELPDESK',
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
                'Atendimento a motoristas e passageiros da plataforma KupOn',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Atualizar fila',
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

  Widget _buildKpiSection(int open, int urgent, int closed) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  _kpiCard(
                    title: 'TOTAL DE CHAMADOS',
                    value: '${_tickets.length}',
                    icon: Icons.all_inbox_rounded,
                    color: AppTheme.primaryContainer,
                    subtitle: 'Histórico na plataforma',
                  ),
                  const SizedBox(width: 12),
                  _kpiCard(
                    title: 'CHAMADOS ABERTOS',
                    value: '$open',
                    icon: Icons.hourglass_top_rounded,
                    color: const Color(0xFFF5C842),
                    subtitle: 'Aguardando resolução',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _kpiCard(
                    title: 'ALERTA URGENTE',
                    value: '$urgent',
                    icon: Icons.priority_high_rounded,
                    color: const Color(0xFFCF6679),
                    subtitle: 'Prioridade máxima',
                  ),
                  const SizedBox(width: 12),
                  _kpiCard(
                    title: 'RESOLVIDOS',
                    value: '$closed',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF4CAF88),
                    subtitle: 'Tickets finalizados',
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            _kpiCard(
              title: 'TOTAL DE CHAMADOS',
              value: '${_tickets.length}',
              icon: Icons.all_inbox_rounded,
              color: AppTheme.primaryContainer,
              subtitle: 'Histórico na plataforma',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'CHAMADOS ABERTOS',
              value: '$open',
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFF5C842),
              subtitle: 'Aguardando suporte',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'ALERTA URGENTE',
              value: '$urgent',
              icon: Icons.priority_high_rounded,
              color: const Color(0xFFCF6679),
              subtitle: 'Prioridade máxima',
            ),
            const SizedBox(width: 12),
            _kpiCard(
              title: 'RESOLVIDOS',
              value: '$closed',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF4CAF88),
              subtitle: 'Tickets finalizados',
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
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: const Color(0xFFE5E2E1),
              ),
              decoration: InputDecoration(
                hintText: 'Pesquisar ticket por assunto, usuário, mensagem...',
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
              value: _selectedPriorityFilter,
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
                DropdownMenuItem(value: 'all', child: Text('Prioridade: Todas')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                DropdownMenuItem(value: 'high', child: Text('Alta')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'low', child: Text('Baixa')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedPriorityFilter = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return _emptyState(
        _searchQuery.isNotEmpty
            ? 'Nenhum ticket corresponde à pesquisa "$_searchQuery".'
            : 'Nenhum ticket encontrado nesta fila.',
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
        itemBuilder: (_, i) => _buildTicketTile(items[i]),
      ),
    );
  }

  Widget _buildTicketTile(Map<String, dynamic> ticket) {
    final user = ticket['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Usuário';
    final photo = user['photo_url'] as String?;
    final phone = user['phone'] as String?;
    final subject = ticket['subject'] as String? ?? 'Sem assunto';
    final body = ticket['description'] as String? ?? '';
    final status = ticket['status'] as String? ?? 'open';
    final priority = ticket['priority'] as String? ?? 'normal';
    final date = _fmtDate(ticket['created_at']);

    final isOpen = _isOpenStatus(status);
    final isUrgent = priority == 'urgent';

    final statusColor = isOpen ? const Color(0xFFF5C842) : const Color(0xFF4CAF88);
    final priorityColor = isUrgent
        ? const Color(0xFFCF6679)
        : priority == 'high'
            ? const Color(0xFFF5C842)
            : const Color(0xFFE2BFB0).withValues(alpha: 0.7);

    return InkWell(
      onTap: () {
        setState(() => _openTicket = ticket);
        _loadReplies(ticket['id'] as String);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUrgent && isOpen
                ? const Color(0xFFCF6679).withValues(alpha: 0.45)
                : AppTheme.outlineVariant.withValues(alpha: 0.3),
            width: isUrgent && isOpen ? 1.2 : 1,
          ),
          boxShadow: [
            if (isUrgent && isOpen)
              BoxShadow(
                color: const Color(0xFFCF6679).withValues(alpha: 0.08),
                blurRadius: 12,
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      _statusChip(isOpen ? 'Aberto' : 'Resolvido', statusColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subject,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE5E2E1),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flag_rounded, size: 10, color: priorityColor),
                            const SizedBox(width: 4),
                            Text(
                              _priorityLabel(priority),
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: priorityColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.schedule_outlined,
                        size: 12,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                        ),
                      ),
                      if (phone != null && phone.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          '•  $phone',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: const Color(0xFFE2BFB0).withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFE2BFB0),
              size: 20,
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

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTicketDetail(Map<String, dynamic> ticket) {
    final user = ticket['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Usuário';
    final photo = user['photo_url'] as String?;
    final phone = user['phone'] as String? ?? '–';
    final subject = ticket['subject'] as String? ?? '–';
    final body = ticket['description'] as String? ?? '–';
    final status = ticket['status'] as String? ?? 'open';
    final priority = ticket['priority'] as String? ?? 'normal';

    final isOpen = _isOpenStatus(status);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainerLow,
        elevation: 0,
        leading: IconButton(
          onPressed: () => setState(() => _openTicket = null),
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFE2BFB0)),
        ),
        title: Text(
          'Atendimento do Chamado',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFE5E2E1),
          ),
        ),
        actions: [
          if (isOpen)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: FilledButton.icon(
                  onPressed: () => _closeTicket(ticket['id'] as String),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF93000A),
                    foregroundColor: const Color(0xFFFFDAD6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text(
                    'Concluir Chamado',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFE5E2E1),
                                ),
                              ),
                              Text(
                                'Telefone: $phone • Criado ${_fmtDate(ticket['created_at'])}',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11.5,
                                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _statusChip(
                              isOpen ? 'Aberto' : 'Resolvido',
                              isOpen ? const Color(0xFFF5C842) : const Color(0xFF4CAF88),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Prioridade: ${_priorityLabel(priority)}',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: priority == 'urgent'
                                    ? const Color(0xFFCF6679)
                                    : const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ASSUNTO',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subject,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE5E2E1),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 16,
                              color: AppTheme.primaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Mensagem Inicial do Usuário',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          body,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13.5,
                            height: 1.5,
                            color: const Color(0xFFE5E2E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'HISTÓRICO DE RESPOSTAS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_ticketReplies.length}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE2BFB0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingReplies)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_ticketReplies.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Nenhuma resposta enviada ainda. Escreva uma resposta abaixo.',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _ticketReplies.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final reply = _ticketReplies[i];
                        final isAdmin = reply['is_staff'] == true;
                        final replyUser = reply['users'] as Map<String, dynamic>? ?? {};
                        final senderName =
                            (replyUser['name'] as String? ?? '').trim().isNotEmpty
                                ? replyUser['name'] as String
                                : name;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? AppTheme.primaryContainer.withValues(alpha: 0.08)
                                : AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAdmin
                                  ? AppTheme.primaryContainer.withValues(alpha: 0.25)
                                  : AppTheme.outlineVariant.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                                    size: 14,
                                    color: isAdmin ? AppTheme.primaryContainer : const Color(0xFFE2BFB0),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isAdmin ? 'Suporte KupOn (Admin)' : senderName,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isAdmin ? AppTheme.primaryContainer : const Color(0xFFE5E2E1),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _fmtDate(reply['created_at']),
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 10,
                                      color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                reply['message'] ?? '',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  color: const Color(0xFFE5E2E1),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          if (isOpen)
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                border: Border(
                  top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _replyCtrl,
                        maxLines: 3,
                        minLines: 1,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          color: const Color(0xFFE5E2E1),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Escrever resposta para o usuário...',
                          hintStyle: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: const Color(0xFFE2BFB0).withValues(alpha: 0.35),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      final text = _replyCtrl.text.trim();
                      if (text.isEmpty) return;
                      final ok =
                          await _sendReply(ticket['id'] as String, text);
                      if (ok) _replyCtrl.clear();
                      _loadReplies(ticket['id'] as String);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryContainer.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.black,
                        size: 20,
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

  Future<bool> _sendReply(String ticketId, String text) async {
    if (text.trim().isEmpty) return false;
    final senderId = _db.auth.currentUser?.id;
    if (senderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão expirada. Inicie sessão novamente.'),
            backgroundColor: Color(0xFFCF6679),
          ),
        );
      }
      return false;
    }
    try {
      await _db.from('support_replies').insert({
        'ticket_id': ticketId,
        'sender_id': senderId,
        'message': text.trim(),
        'is_staff': true,
      });
      try {
        await _db
            .from('support_tickets')
            .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', ticketId);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resposta enviada ao usuário.'),
            backgroundColor: Color(0xFF4CAF88),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar resposta: $e'),
            backgroundColor: const Color(0xFFCF6679),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _closeTicket(String ticketId) async {
    try {
      await _db
          .from('support_tickets')
          .update({
            'status': 'resolved',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', ticketId);
      setState(() {
        _openTicket?['status'] = 'resolved';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chamado concluído com sucesso.'),
            backgroundColor: Color(0xFF4CAF88),
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao concluir ticket: $e'),
            backgroundColor: const Color(0xFFCF6679),
          ),
        );
      }
    }
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'urgent':
        return 'Urgente';
      case 'high':
        return 'Alta';
      case 'low':
        return 'Baixa';
      default:
        return 'Normal';
    }
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
                Icons.support_agent_outlined,
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

  String _fmtDate(dynamic v) {
    if (v is! String || v.isEmpty) return '–';
    final d = DateTime.tryParse(v);
    if (d == null) return '–';
    final local = d.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month ${local.year} $hour:$minute';
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
