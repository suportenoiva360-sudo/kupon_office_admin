import 'package:supabase_flutter/supabase_flutter.dart';

class PromotionsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> validateCode(String code, int tripFare) async {
    final result = await _client
        .from('promotions')
        .select()
        .eq('code', code.toUpperCase())
        .eq('is_active', true)
        .lte('start_date', DateTime.now().toIso8601String())
        .gte('end_date', DateTime.now().toIso8601String())
        .maybeSingle();

    if (result == null) return null;

    final minFare = result['min_fare'] as int?;
    if (minFare != null && tripFare < minFare) {
      return {'error': 'Valor mínimo da viagem: Kup $minFare'};
    }

    final maxUses = result['max_uses'] as int?;
    final currentUses = result['current_uses'] as int? ?? 0;
    if (maxUses != null && currentUses >= maxUses) {
      return {'error': 'Cupom esgotado'};
    }

    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      final maxPerUser = result['max_uses_per_user'] as int?;
      if (maxPerUser != null) {
        final userUses = await _client
            .from('promotion_uses')
            .select('id')
            .eq('promotion_id', result['id'])
            .eq('user_id', userId);
        if (userUses.length >= maxPerUser) {
          return {'error': 'Você já usou este cupom'};
        }
      }
    }

    final discountType = result['discount_type'] as String;
    final discountValue = result['discount_value'] as int;
    final maxDiscount = result['max_discount'] as int?;

    int discount;
    if (discountType == 'percentage') {
      discount = (tripFare * discountValue / 100).round();
      if (maxDiscount != null && discount > maxDiscount) {
        discount = maxDiscount;
      }
    } else {
      discount = discountValue;
    }

    if (discount > tripFare) discount = tripFare;

    return {
      'promotion_id': result['id'],
      'code': result['code'],
      'name': result['name'],
      'description': result['description'],
      'discount': discount,
      'discount_type': discountType,
      'discount_value': discountValue,
    };
  }

  Future<void> recordUse(String promotionId, String userId, String? tripId) async {
    await _client.from('promotion_uses').insert({
      'promotion_id': promotionId,
      'user_id': userId,
      'trip_id': tripId,
    });

    await _client.rpc('increment_promotion_uses', params: {
      'p_promotion_id': promotionId,
    });
  }
}
