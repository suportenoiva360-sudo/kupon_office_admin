import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kupon_office_admin/core/widgets/app_snackbar.dart';

/// Secção "Pagamentos" do pouco de financeiro — pedidos de recarga/saque
/// da carteira por mobile money ou dinheiro (na sede) que precisam de aprovação
/// do admin para se reflectirem na conta do utilizador.
///
/// Política de métodos do KupON: só 4 — assinatura (cotas consumidas por Km),
/// dinheiro, mobile money e carteira. Nesta secção apenas mobile money e
/// dinheiro são válidos; qualquer outro método aparece marcado como fora da
/// política para o admin rejeitar.
///
/// Carrega [payment_requests] com status 'pending' (uma vez, com guard
/// `_initialized`), subscreve realtime de inserção para novos pedidos e
/// expõe `decide()` que chama o RPC atómico `decide_payment_request`
/// (approve → `add_credits` na mesma transacção). Nenhum backend novo.
class PaymentRequestsSection extends StatefulWidget {
  final String adminId;
  const PaymentRequestsSection({super.key, required this.adminId});

  @override
  State<PaymentRequestsSection> createState() => _PaymentRequestsSectionState();
}

class _PaymentRequestsSectionState extends State<PaymentRequestsSection> {
  final _client = Supabase.instance.client;
  final List<Map<String, dynamic>> _requests = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _initialized = false;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadPending();
    if (!mounted) return;
    _subscribeRealtime();
  }

  Future<void> _loadPending() async {
    try {
      final rows = await _client
          .from('payment_requests')
          .select(
            'id,user_id,method,direction,amount,reference,status,'
            'created_at,users!inner(name,phone)',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _requests
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(rows));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _client
        .channel('admin-payments-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'payment_requests',
          callback: (payload) {
            if (payload.newRecord['status'] == 'pending') {
              _loadPending();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'payment_requests',
          callback: (_) => _loadPending(),
        )
        .subscribe();
  }

  Future<void> _decide(Map<String, dynamic> req, String decision) async {
    final id = req['id'];
    if (_busyId != null) return;
    setState(() => _busyId = id as String?);
    try {
      await _client.rpc(
        'decide_payment_request',
        params: {
          'p_request_id': id,
          'p_decision': decision, // 'approved' | 'rejected'
          'p_admin_id': widget.adminId,
        },
      );
      if (!mounted) return;
      setState(() => _busyId = null);
      showAdminSnackBar(
        context,
        message: decision == 'approved'
            ? 'Pagamento aprovado — crédito reflectido na conta.'
            : 'Pagamento rejeitado.',
        type: decision == 'approved'
            ? AdminSnackType.success
            : AdminSnackType.warning,
      );
      await _loadPending();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      showAdminSnackBar(
        context,
        message: 'Erro ao decidir pagamento: $e',
        type: AdminSnackType.error,
      );
    }
  }

  @override
  void dispose() {
    // Cancelar a subscrição explicitamente (sem guardar callback pendente)
    // garante que nenhum realtime callback acede a este State após o dispose.
    _channel?.unsubscribe();
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_requests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Sem pagamentos pendentes de aprovação.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      itemCount: _requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildRequestCard(_requests[i]),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final users = (req['users'] as Map?) ?? const {};
    final name = users['name'] as String? ?? ' Utilizador';
    final method = req['method'] as String? ?? '';
    final amount = (req['amount'] as num?)?.toInt() ?? 0;
    final reference = req['reference'] as String? ?? '—';

    // Política: só mobile money e dinheiro entram como recarga validada.
    // 'assinatura' e 'carteira' são métodos de corrida, nunca de top-up.
    final (methodLabel, icon, isPolicyMethod) = switch (method.toLowerCase()) {
      'mobile_money' || 'mobile money' => (
        'Mobile Money (M-Pesa / EMIS)',
        Icons.phone_iphone_rounded,
        true,
      ),
      'cash' || 'dinheiro' => ('Dinheiro', Icons.payments_rounded, true),
      _ => (
        method.isEmpty ? 'Método não definido' : '$method — FORA DA POLÍTICA',
        Icons.currency_exchange_rounded,
        false,
      ),
    };

    final isWithdrawal = req['direction'] == 'saque';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: const Color(0xFFFF6B00)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE5E2E1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$methodLabel • ${isWithdrawal ? "Saque" : "Recarga"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isPolicyMethod
                            ? const Color(0xFFB0A8A0)
                            : const Color(0xFFCF6679),
                      ),
                    ),
                    if (!isPolicyMethod) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Recusar — só Dinheiro, Mobile Money, Assinatura ou Carteira.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFCF6679).withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${isWithdrawal ? "-" : "+"}${amount.toStringAsFixed(2)} Kz',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isWithdrawal
                      ? const Color(0xFFE0885C)
                      : const Color(0xFF6FCF97),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Ref: $reference',
            style: const TextStyle(fontSize: 12, color: Color(0xFFB0A8A0)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _busyId == null
                    ? () => _decide(req, 'rejected')
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFCF6679),
                  side: const BorderSide(color: Color(0xFF8A3F2E)),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Rejeitar'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: (_busyId == null && isPolicyMethod)
                    ? () => _decide(req, 'approved')
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: isPolicyMethod
                      ? const Color(0xFF0E5C46)
                      : const Color(0xFF3A3A3A),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Aprovar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
