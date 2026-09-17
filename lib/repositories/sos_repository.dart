import 'package:supabase_flutter/supabase_flutter.dart';

class SosRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String?> createAlert({
    required String userId,
    String? driverId,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? address,
    String? phone,
  }) async {
    final result = await _client
        .from('sos_alerts')
        .insert({
          'driver_id': driverId,
          'user_id': userId,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'address': address,
          'phone': phone,
        })
        .select('id')
        .single();
    return result['id'] as String?;
  }

  Future<Map<String, dynamic>?> getActiveAlert(String userId) async {
    try {
      return await _client
          .from('sos_alerts')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateLocation(
    String alertId, {
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    await _client.from('sos_alerts').update({
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    }).eq('id', alertId);
  }

  Future<void> setStatus(String alertId, String status) async {
    await _client
        .from('sos_alerts')
        .update({'status': status})
        .eq('id', alertId);
  }
}
