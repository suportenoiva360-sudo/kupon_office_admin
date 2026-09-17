import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getPlans() async {
    return await _client
        .from('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('price');
  }

  Future<Map<String, dynamic>?> getActiveSubscription(String userId) async {
    return await _client
        .from('subscriptions')
        .select('*, subscription_plans(*)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> subscribe(
    String userId,
    String planId,
    String paymentMethod,
  ) async {
    final plans = await _client
        .from('subscription_plans')
        .select()
        .eq('id', planId)
        .single();

    // Cancelar subscrições ativas anteriores
    await _client
        .from('subscriptions')
        .update({'status': 'cancelled'})
        .eq('user_id', userId)
        .eq('status', 'active');

    final startDate = DateTime.now();
    final endDate = DateTime.now().add(const Duration(days: 30));

    final subscription = await _client.from('subscriptions').insert({
      'user_id': userId,
      'plan_id': planId,
      'status': 'active',
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'payment_method': paymentMethod,
    }).select().single();

    debugPrint('Subscription criada: ${subscription['id']}');

    final creditsAmount = (plans['credits'] as num).toInt();

    debugPrint('Adicionando $creditsAmount créditos');

    try {
      await _client.rpc('add_credits', params: {
        'p_user_id': userId,
        'p_amount': creditsAmount,
        'p_description': 'Assinatura ${plans['name']}',
        'p_type': 'subscription',
      });
      debugPrint('add_credits OK');
    } catch (e) {
      debugPrint('ERRO add_credits via RPC: $e');
      debugPrint('Tentando adicionar créditos diretamente...');
      try {
        final existing = await _client
            .from('credits')
            .select('balance')
            .eq('user_id', userId)
            .maybeSingle();
        final current = (existing?['balance'] as num?)?.toInt() ?? 0;
        final newBalance = current + creditsAmount;
        if (existing != null) {
          await _client
              .from('credits')
              .update({'balance': newBalance}).eq('user_id', userId);
        } else {
          await _client
              .from('credits')
              .insert({'user_id': userId, 'balance': newBalance});
        }
        await _client.from('credit_transactions').insert({
          'user_id': userId,
          'amount': creditsAmount,
          'type': 'subscription',
          'description': 'Assinatura ${plans['name']}',
          'balance_after': newBalance,
        });
        debugPrint('Créditos adicionados diretamente: $newBalance');
      } catch (e2) {
        debugPrint('ERRO ao adicionar créditos diretamente: $e2');
      }
    }

    return subscription;
  }

  Future<void> cancel(String userId) async {
    final active = await getActiveSubscription(userId);
    if (active != null) {
      await _client
          .from('subscriptions')
          .update({'status': 'cancelled'})
          .eq('id', active['id']);
    }
  }
}
