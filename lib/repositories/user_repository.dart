import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final result = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return result;
  }

  Future<Map<String, dynamic>> updateProfile(String userId, Map<String, dynamic> data) async {
    return await _client
        .from('users')
        .update(data)
        .eq('id', userId)
        .select()
        .single();
  }

  Future<List<Map<String, dynamic>>> getProvinces() async {
    final result = await _client
        .from('provinces')
        .select('id, name')
        .eq('is_active', true)
        .order('name');
    return result;
  }

  Future<List<Map<String, dynamic>>> getTrips(String userId) async {
    return await _client
        .from('trips')
        .select('*, driver:drivers!trips_driver_id_fkey(user:users(photo_url, name))')
        .eq('passenger_id', userId)
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final userId = _client.auth.currentUser?.id;
    final q = query.trim();

    try {
      final nameResults = await _client
          .from('users')
          .select('id, name, email, phone, photo_url')
          .ilike('name', '%$q%')
          .neq('id', userId ?? '')
          .limit(10);

      if (nameResults.isNotEmpty) return nameResults;

      final emailResults = await _client
          .from('users')
          .select('id, name, email, phone, photo_url')
          .ilike('email', '%$q%')
          .neq('id', userId ?? '')
          .limit(10);

      if (emailResults.isNotEmpty) return emailResults;

      final phoneResults = await _client
          .from('users')
          .select('id, name, email, phone, photo_url')
          .ilike('phone', '%$q%')
          .neq('id', userId ?? '')
          .limit(10);

      return phoneResults;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecentTransferContacts(String userId) async {
    final sent = await _client
        .from('credit_transactions')
        .select('note')
        .eq('user_id', userId)
        .eq('type', 'transfer_sent')
        .not('note', 'is', null)
        .order('created_at', ascending: false)
        .limit(20);

    final contactIds = <String>{};
    for (final tx in sent) {
      final note = tx['note'] as String?;
      if (note != null && note.isNotEmpty) {
        contactIds.add(note);
      }
    }

    if (contactIds.isEmpty) return [];

    final contacts = <Map<String, dynamic>>[];
    for (final cid in contactIds.take(4)) {
      final user = await _client
          .from('users')
          .select('id, name, photo_url')
          .eq('id', cid)
          .maybeSingle();
      if (user != null) contacts.add(user);
    }

    return contacts;
  }
}
