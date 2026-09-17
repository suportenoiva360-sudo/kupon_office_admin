import 'package:supabase_flutter/supabase_flutter.dart';

class SupportRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> createTicket({
    required String userId,
    required String category,
    required String subject,
    required String description,
    String? tripId,
  }) async {
    final result = await _client.from('support_tickets').insert({
      'user_id': userId,
      'category': category,
      'subject': subject,
      'description': description,
      'trip_id': ?tripId,
    }).select('id').single();
    return result['id'] as String;
  }

  Future<List<Map<String, dynamic>>> getTickets(String userId) async {
    return await _client
        .from('support_tickets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getTicketReplies(String ticketId) async {
    return await _client
        .from('support_replies')
        .select('*, users!support_replies_sender_id_fkey(name, photo_url)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
  }

  Future<void> addReply({
    required String ticketId,
    required String senderId,
    required String message,
  }) async {
    await _client.from('support_replies').insert({
      'ticket_id': ticketId,
      'sender_id': senderId,
      'message': message,
    });
  }
}
