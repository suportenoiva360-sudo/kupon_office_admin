import 'package:supabase_flutter/supabase_flutter.dart';

class WalletRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<int> getBalance(String userId) async {
    final result = await _client
        .from('credits')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();
    return result?['balance'] ?? 0;
  }

  Future<void> addCredits(
    String userId,
    int amount,
    String description,
    String type,
  ) async {
    await _client.rpc('add_credits', params: {
      'p_user_id': userId,
      'p_amount': amount,
      'p_description': description,
      'p_type': type,
    });
  }

  Future<void> deductCredits(
    String userId,
    int amount,
    String description,
    String? tripId,
  ) async {
    await _client.rpc('deduct_credits', params: {
      'p_user_id': userId,
      'p_amount': amount,
      'p_description': description,
      'p_trip_id': tripId,
    });
  }

  Future<List<Map<String, dynamic>>> getHistory(String userId) async {
    return await _client
        .from('credit_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
  }

  /// Soma das reservas (trip_hold) ainda ativas — sem pagamento nem
  /// devolução associados. Usada para exibir o valor reservado na carteira.
  Future<int> getReservedAmount(String userId) async {
    try {
      final holds = await _client
          .from('credit_transactions')
          .select('amount,trip_id')
          .eq('user_id', userId)
          .eq('type', 'trip_hold')
          .order('created_at', ascending: false)
          .limit(10);
      final settled = await _client
          .from('credit_transactions')
          .select('trip_id')
          .eq('user_id', userId)
          .inFilter('type', ['trip_payment', 'trip_hold_release'])
          .order('created_at', ascending: false)
          .limit(50);
      final settledTrips =
          settled.map((r) => r['trip_id'] as String? ?? '').toSet();
      var total = 0;
      for (final h in holds) {
        final tripId = h['trip_id'] as String?;
        if (tripId != null && !settledTrips.contains(tripId)) {
          total += ((h['amount'] as int?) ?? 0).abs();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> transferCredits(
    String fromUserId,
    String toUserId,
    int amount,
    String? note,
  ) async {
    await _client.rpc('transfer_credits', params: {
      'p_from_user_id': fromUserId,
      'p_to_user_id': toUserId,
      'p_amount': amount,
      'p_note': note,
    });
  }
}
