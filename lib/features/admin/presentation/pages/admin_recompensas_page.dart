import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/app/widgets/kupon_loader.dart';

/// 3.1 — Fila de aprovação das recompensas por convite.
/// Lista `referral_rewards` (RLS admin) com realtime; aprovar/rejeitar
/// via RPC `decide_referral_reward` (rejeição exige motivo).
class AdminRecompensasPage extends StatefulWidget {
  const AdminRecompensasPage({super.key});

  @override
  State<AdminRecompensasPage> createState() => _AdminRecompensasPageState();
}

class _AdminRecompensasPageState extends State<AdminRecompensasPage> {
  final SupabaseClient _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  List<Map<String, dynamic>> _rewards = [];
  bool _loading = true;
  bool _pendingOnly = true; // Pendentes | Histórico
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _db.removeChannel(_channel!);
    super.dispose();
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('recompensas-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'referral_rewards',
          callback: (payload) => _load(),
        )
        .subscribe();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = _rewards.isEmpty;
      _error = null;
    });
    try {
      var query = _db
          .from('referral_rewards')
          .select(
            'id,referral_id,referrer_id,referred_id,amount,status,'
            'rejection_reason,decided_at,created_at,'
            'referrer:users!referral_rewards_referrer_fk(id,name,phone),'
            'referred:users!referral_rewards_referred_fk(id,name,phone)',
          );
      if (_pendingOnly) {
        query = query.inFilter('status', ['pending', 'in_review']);
      }
      final rows = await query.order('created_at', ascending: false).limit(100);
      if (!mounted) return;
      setState(() {
        _rewards = [for (final r in (rows as List)) Map.from(r as Map)];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as recompensas.';
        _loading = false;
      });
    }
  }

  Future<void> _decide(Map<String, dynamic> reward, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason(reward);
      if (reason == null) return; // cancelado
      if (reason.trim().isEmpty) {
        _snack('O motivo da rejeição é obrigatório.', const Color(0xFFCF6679));
        return;
      }
    }
    try {
      await _db.rpc(
        'decide_referral_reward',
        params: {
          'p_reward_id': reward['id'],
          'p_approve': approve,
          'p_reason': reason,
        },
      );
      if (!mounted) return;
      _snack(
        approve
            ? 'Recompensa aprovada e creditada.'
            : 'Recompensa rejeitada.',
        const Color(0xFF4CAF88),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      _snack(
        msg.contains('já decidida')
            ? 'Essa recompensa já foi decidida por outro admin.'
            : 'Erro ao decidir a recompensa.',
        const Color(0xFFCF6679),
      );
      await _load();
    }
  }

  Future<String?> _askReason(Map<String, dynamic> reward) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B1B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Rejeitar recompensa',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE5E2E1),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${reward['referrer']?['name'] ?? 'Convidante'} · '
              '${reward['amount'] ?? '?'} Kz',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: const Color(0xFF9C9896),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 2,
              autofocus: true,
              style: TextStyle(fontSize: 13, color: const Color(0xFFE5E2E1)),
              decoration: const InputDecoration(
                hintText: 'Motivo (obrigatório — vai ao convidante)',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF5C5856)),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF9C9896))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF93000A)),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: _loading
            ? const Center(child: KuponLoader())
            : RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.primaryContainer,
                backgroundColor: AppTheme.surfaceContainerLow,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildTabs(),
                      const SizedBox(height: 16),
                      if (_error != null) _errorBanner(),
                      if (_rewards.isEmpty && _error == null) _empty(),
                      ..._rewards.map(_buildRewardCard),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final pending = _rewards
        .where((r) => r['status'] == 'pending' || r['status'] == 'in_review')
        .length;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryContainer.withValues(alpha: 0.3)),
          ),
          child: const Icon(
            Icons.card_giftcard_rounded,
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
                    'Recompensas de Convites',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE5E2E1),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (pending > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF93000A).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$pending PENDENTES',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFB4AB),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Aprovação das recompensas de convites — credita ao convidante só após validação',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Recarregar',
          onPressed: _load,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: Color(0xFFE5E2E1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        _tab('Pendentes', _pendingOnly),
        const SizedBox(width: 8),
        _tab('Histórico', !_pendingOnly),
      ],
    );
  }

  Widget _tab(String label, bool active) {
    return GestureDetector(
      onTap: () {
        if (!active) {
          setState(() => _pendingOnly = !_pendingOnly);
          _load();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryContainer.withValues(alpha: 0.15)
              : AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppTheme.primaryContainer
                : AppTheme.surfaceContainerHighest,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? AppTheme.primaryContainer : AppTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF93000A).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFFB4AB), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFFFB4AB)),
            ),
          ),
          TextButton(
            onPressed: _load,
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceContainerHighest),
      ),
      child: Column(
        children: [
          Icon(
            Icons.card_giftcard_outlined,
            size: 40,
            color: const Color(0xFFE2BFB0).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          Text(
            _pendingOnly
                ? 'Nenhuma recompensa pendente'
                : 'Sem histórico de recompensas',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> r) {
    final referrer = (r['referrer'] as Map?) ?? const {};
    final referred = (r['referred'] as Map?) ?? const {};
    final pending =
        r['status'] == 'pending' || r['status'] == 'in_review';
    final created = DateTime.tryParse('${r['created_at'] ?? ''}');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _party('CONVIDANTE (recebe)', referrer),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.4),
                ),
              ),
              Expanded(
                child: _party('CONVIDADO', referred),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${r['amount'] ?? '?'} Kz',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _statusChip('${r['status'] ?? ''}'),
              const Spacer(),
              Text(
                created == null ? '—' : _fmt(created),
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          if (r['rejection_reason'] != null &&
              '${r['rejection_reason']}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo da rejeição: ${r['rejection_reason']}',
              style: TextStyle(
                fontSize: 11.5,
                color: const Color(0xFFFFB4AB).withValues(alpha: 0.8),
              ),
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    'Aprovar e creditar',
                    Icons.check_circle_outline_rounded,
                    const Color(0xFF4CAF88),
                    () => _decide(r, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionBtn(
                    'Rejeitar (motivo)',
                    Icons.cancel_outlined,
                    const Color(0xFFFFB4AB),
                    () => _decide(r, false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _party(String label, Map parties) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: const Color(0xFF9C9896),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          parties['name']?.toString() ?? '—',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE5E2E1),
          ),
        ),
        if (parties['phone'] != null)
          Text(
            '${parties['phone']}',
            style: TextStyle(
              fontSize: 10.5,
              color: const Color(0xFFE2BFB0).withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'approved' => ('Aprovada', const Color(0xFF4CAF88)),
      'rejected' => ('Rejeitada', const Color(0xFFFFB4AB)),
      'in_review' => ('Em análise', const Color(0xFFFFB74D)),
      _ => ('Pendente', const Color(0xFFFFB74D)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
