import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cancelamentos e dívidas [fase 4]: dívidas de passageiros (taxas de
/// cancelamento), compensações aos motoristas, contestações em aberto e
/// o log de decisões. Ação principal: REVERTER COBRANÇA (RPC reverse_charge)
/// para contestações procedentes e no-shows injustos — devolve os créditos
/// capturados ao passageiro e anula a compensação do motorista.
class AdminCancelamentosPage extends StatefulWidget {
  const AdminCancelamentosPage({super.key});

  @override
  State<AdminCancelamentosPage> createState() => _AdminCancelamentosPageState();
}

class _AdminCancelamentosPageState extends State<AdminCancelamentosPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _busy = false;
  String _filter = 'all';

  List<Map<String, dynamic>> _debts = [];
  List<Map<String, dynamic>> _comps = [];
  List<Map<String, dynamic>> _log = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final debts = await _db
          .from('passenger_debts')
          .select('*, users(name, phone)')
          .order('created_at', ascending: false)
          .limit(200);
      final comps = await _db
          .from('driver_compensations')
          .select('*, drivers(users(name, phone)), trips(pickup_name, destination_name)')
          .order('created_at', ascending: false)
          .limit(200);
      final log = await _db
          .from('cancel_decisions_log')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _debts = List<Map<String, dynamic>>.from(debts);
        _comps = List<Map<String, dynamic>>.from(comps);
        _log = List<Map<String, dynamic>>.from(log);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Erro ao carregar: $e', error: true);
    }
  }

  String _debtState(String state) {
    switch (state) {
      case 'pending':
        return 'Pendente';
      case 'paid':
        return 'Paga';
      case 'waived':
        return 'Anulada';
      case 'contested':
        return 'Contestada';
      case 'under_review':
        return 'Em análise';
      default:
        return state;
    }
  }

  Color _debtColor(String state) {
    switch (state) {
      case 'paid':
        return const Color(0xFF4CAF88);
      case 'pending':
        return const Color(0xFFFFB74D);
      case 'contested':
      case 'under_review':
        return const Color(0xFFFF1F48);
      case 'waived':
        return const Color(0xFF8A8482);
      default:
        return const Color(0xFF8A8482);
    }
  }

  String _compState(String state) {
    switch (state) {
      case 'pending':
        return 'A regularizar';
      case 'approved':
        return 'Parcial';
      case 'paid':
        return 'Creditada';
      case 'reversed':
        return 'Anulada';
      case 'under_review':
        return 'Em análise';
      default:
        return state;
    }
  }

  Color _compColor(String state) {
    switch (state) {
      case 'paid':
        return const Color(0xFF4CAF88);
      case 'approved':
      case 'pending':
        return const Color(0xFFFFB74D);
      case 'reversed':
        return const Color(0xFF8A8482);
      default:
        return const Color(0xFFFF1F48);
    }
  }

  Future<void> _reverseCharge(Map<String, dynamic> debt) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        title: Text(
          'Reverter cobrança',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE5E2E1),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Devolve ${(debt['amount_paid'] ?? 0)} Kz de créditos ao '
              'passageiro e anula a compensação do motorista (teto = saldo '
              'dele).',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: const Color(0xFFE2BFB0),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: const Color(0xFFE5E2E1),
              ),
              decoration: const InputDecoration(
                hintText: 'Nota da decisão (obrigatória)',
                hintStyle: TextStyle(color: Color(0xFFE2BFB0)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: const Color(0xFF050505),
            ),
            onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim(),
            ),
            child: Text(
              'Reverter',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) {
      _toast('Nota obrigatória para reverter.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _db.rpc(
        'reverse_charge',
        params: {'p_debt_id': debt['id'], 'p_note': note},
      );
      if (!mounted) return;
      _toast('Cobrança revertida.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Erro ao reverter: $e', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: const Color(0xFFE5E2E1)),
        ),
        backgroundColor: error ? const Color(0xFFCF6679) : AppTheme.primaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contested = _debts.where((d) => d['state'] == 'contested').toList();
    final pending = _debts.where((d) => d['state'] == 'pending').toList();
    final paidCount = _debts.where((d) => d['state'] == 'paid').length;
    final compsPending = _comps
        .where((c) => c['state'] == 'pending' || c['state'] == 'approved')
        .fold<int>(0, (s, c) => s + (c['amount'] as int? ?? 0));

    final filtered = _filter == 'all'
        ? _debts
        : _debts.where((d) => d['state'] == _filter).toList();

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
                  const SizedBox(height: 16),
                  _buildKpis(contested.length, pending.length, paidCount, compsPending),
                  const SizedBox(height: 24),
                  if (contested.isNotEmpty) ...[
                    _buildSectionTitle('Contestações em aberto', Icons.flag_rounded),
                    const SizedBox(height: 8),
                    ...contested.map(_buildConCard),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('Dívidas', Icons.receipt_long_rounded),
                  const SizedBox(height: 8),
                  _buildFilters(),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    _buildEmpty(filtered.length == _debts.length
                        ? 'Sem dívidas registadas'
                        : 'Nada neste filtro')
                  else
                    ...filtered.map(_buildDebtCard),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Compensações aos motoristas', Icons.payments_rounded),
                  const SizedBox(height: 8),
                  if (_comps.isEmpty)
                    _buildEmpty('Sem compensações registadas')
                  else
                    ..._comps.map(_buildCompCard),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Histórico de decisões', Icons.history_rounded),
                  const SizedBox(height: 8),
                  if (_log.isEmpty)
                    _buildEmpty('Sem decisões registadas')
                  else
                    ..._log.map(_buildLogCard),
                  const SizedBox(height: 32),
                ],
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
                color: AppTheme.primaryContainer.withValues(alpha: 0.3)),
          ),
          child: const Icon(
            Icons.cancel_presentation_rounded,
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
                'Cancelamentos e dívidas',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFE5E2E1),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Taxas de compensação, dívidas de passageiros e contestações',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                ),
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
                  color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.refresh_rounded,
                color: Color(0xFFE5E2E1), size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildKpis(
      int contested, int pending, int paid, int compsPending) {
    Widget kpi(String label, String value, Color color) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
            child: kpi('Contestações abertas', contested.toString(),
                const Color(0xFFFF1F48))),
        const SizedBox(width: 10),
        Expanded(
            child: kpi('Dívidas pendentes', pending.toString(),
                const Color(0xFFFFB74D))),
        const SizedBox(width: 10),
        Expanded(
            child: kpi('Canceladores pagos', paid.toString(),
                const Color(0xFF4CAF88))),
        const SizedBox(width: 10),
        Expanded(
            child: kpi('Comps. a regularizar', '$compsPending Kz',
                const Color(0xFFFFB74D))),
      ],
    );
  }

  Widget _buildSectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryContainer),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE5E2E1),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    const filters = [
      ('all', 'Todas'),
      ('contested', 'Contestadas'),
      ('pending', 'Pendentes'),
      ('paid', 'Pagas'),
      ('waived', 'Anuladas'),
    ];
    return Wrap(
      spacing: 8,
      children: [
        for (final (value, label) in filters)
          ChoiceChip(
            label: Text(label),
            selected: _filter == value,
            onSelected: (_) => setState(() => _filter = value),
            selectedColor: AppTheme.primaryContainer,
            labelStyle: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _filter == value
                  ? const Color(0xFF050505)
                  : const Color(0xFFE2BFB0),
            ),
            backgroundColor: AppTheme.surfaceContainerLow,
          ),
      ],
    );
  }

  Widget _buildEmpty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  String _fmtDate(Object? v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _shortTrip(Object? tripId) {
    final t = tripId?.toString() ?? '';
    return t.length >= 8 ? t.substring(0, 8) : t;
  }

  Widget _buildDebtCard(Map<String, dynamic> d) {
    final state = d['state'] as String? ?? 'pending';
    final amount = d['amount'] as int? ?? 0;
    final paid = d['amount_paid'] as int? ?? 0;
    final user = d['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: state == 'contested'
              ? const Color(0xFFFF1F48).withValues(alpha: 0.5)
              : AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE5E2E1),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _debtColor(state).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _debtState(state),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _debtColor(state),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$amount Kz · capturado $paid Kz · dívida ${_shortTrip(d['trip_id'])} · ${_fmtDate(d['created_at'])}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: const Color(0xFFE2BFB0),
                  ),
                ),
                if (d['contest_note'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Contestação: ${d['contest_note']}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFFF1F48),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (state != 'waived')
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryContainer,
                foregroundColor: const Color(0xFF050505),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
              ),
              onPressed: _busy ? null : () => _reverseCharge(d),
              child: Text(
                paid > 0 ? 'Reverter' : 'Anular',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConCard(Map<String, dynamic> d) {
    return _buildDebtCard(d);
  }

  Widget _buildCompCard(Map<String, dynamic> c) {
    final state = c['state'] as String? ?? 'pending';
    final amount = c['amount'] as int? ?? 0;
    final paidAmt = c['paid_amount'] as int? ?? 0;
    final driver = (c['drivers'] as Map<String, dynamic>? ?? {})['users']
        as Map<String, dynamic>? ?? {};
    final name = driver['name']?.toString() ?? '—';
    final trip = c['trips'] as Map<String, dynamic>?;
    final route = trip == null
        ? ''
        : ' · ${trip['pickup_name'] ?? ''} → ${trip['destination_name'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE5E2E1),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _compColor(state).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _compState(state),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _compColor(state),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$amount Kz (creditado $paidAmt Kz)$route',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: const Color(0xFFE2BFB0),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_fmtDate(l['created_at'])} · ${l['decision']} · ${l['note'] ?? ''} · dívida ${_shortTrip(l['debt_id'])}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: const Color(0xFFE2BFB0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
