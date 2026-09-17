import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getDriverByUserId(String userId) async {
    final result = await _client
        .from('drivers')
        .select('*, users!inner(id, name, email, phone, photo_url)')
        .eq('user_id', userId)
        .maybeSingle();
    return result;
  }

  /// Nome da província pelo id (para exibição no perfil).
  Future<String?> getProvinceName(String provinceId) async {
    try {
      final res = await _client
          .from('provinces')
          .select('name')
          .eq('id', provinceId)
          .maybeSingle();
      return res?['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Zonas de alta demanda da província com estatística ao vivo.
  /// O multiplicador é calculado no servidor (RPC get_demand_zones):
  /// escassez = pedidos pendentes vs motoristas online dentro do raio.
  Future<List<Map<String, dynamic>>> getDemandZones(String provinceId) async {
    try {
      final res = await _client.rpc(
        'get_demand_zones',
        params: {'p_province_id': provinceId},
      );
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erro getDemandZones: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOnlineDrivers({
    String? category,
    String? provinceId,
  }) async {
    try {
      var query = _client
          .from('drivers')
          .select('*, users!inner(id, name, photo_url)')
          .eq('is_online', true)
          .eq('is_approved', true);

      if (category != null) {
        query = query.eq('category', category);
      }
      if (provinceId != null && provinceId.isNotEmpty) {
        query = query.eq('province_id', provinceId);
      }

      return await query;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getDriverById(String driverId) async {
    final result = await _client
        .from('drivers')
        .select('*, users!inner(id, name, email, phone, photo_url)')
        .eq('id', driverId)
        .maybeSingle();
    return result;
  }

  Future<void> updateDriverLocation(
    String driverId,
    double lat,
    double lng,
  ) async {
    await _client.from('drivers').update({
      'current_lat': lat,
      'current_lng': lng,
    }).eq('id', driverId);
  }

  Future<void> setOnlineStatus(String driverId, bool isOnline) async {
    await _client.from('drivers').update({
      'is_online': isOnline,
    }).eq('id', driverId);
  }

  /// Campos que o cliente pode alterar no perfil do motorista.
  /// (is_approved, status, rating, total_trips, user_id ficam de fora;
  /// o servidor impõe via trigger trg_protect_drivers_columns.)
  static const Set<String> _editableDriverFields = {
    'category',
    'vehicle_model',
    'vehicle_color',
    'vehicle_plate',
    'vehicle_year',
    'province_id',
  };

  /// Campos editáveis pelo utilizador em users.
  static const Set<String> _editableUserFields = {
    'name',
    'phone',
    'photo_url',
  };

  Future<void> updateProfile(String driverId, Map<String, dynamic> data) async {
    final filtered = Map.of(data)
      ..removeWhere((k, _) => !_editableDriverFields.contains(k));
    await _client.from('drivers').update(filtered).eq('id', driverId);
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    final filtered = Map.of(data)
      ..removeWhere((k, _) => !_editableUserFields.contains(k));
    await _client.from('users').update(filtered).eq('id', userId);
  }

  /// Aceita a viagem apenas se ainda estiver pendente e sem motorista
  /// (primeiro que aceita ganha; os restantes recebem lista vazia).
  Future<bool> acceptTrip(String tripId, String driverId) async {
    final result = await _client.from('trips').update({
      'driver_id': driverId,
      'status': 'accepted',
    }).eq('id', tripId)
      .eq('status', 'pending')
      .isFilter('driver_id', null)
      .select();
    return result.isNotEmpty;
  }

  /// Inicia a viagem — só a partir de 'accepted' e atribuída ao motorista.
  /// Falha se outro processo alterou entretanto o estado.
  Future<void> startTrip(String tripId, {String? driverId}) async {
    var query = _client.from('trips').update({
      'status': 'in_progress',
      'started_at': DateTime.now().toIso8601String(),
    }).eq('id', tripId)
      .eq('status', 'accepted');
    if (driverId != null && driverId.isNotEmpty) {
      query = query.eq('driver_id', driverId);
    }
    final result = await query.select();
    if (result.isEmpty) {
      throw Exception('Não foi possível iniciar a viagem.');
    }
  }

  /// Cancela a viagem pelo motorista — apenas nos estados 'accepted'
  /// e 'in_progress'; nunca após conclusão.
  Future<void> cancelTrip(String tripId, String? reason,
      {String? driverId}) async {
    var query = _client.from('trips').update({
      'status': 'cancelled',
      'cancel_reason': ?reason,
    }).eq('id', tripId)
      .inFilter('status', ['accepted', 'in_progress']);
    if (driverId != null && driverId.isNotEmpty) {
      query = query.eq('driver_id', driverId);
    }
    final result = await query.select();
    if (result.isEmpty) {
      throw Exception('Não foi possível cancelar a viagem.');
    }
  }

  Future<int> getTodayEarnings(String driverId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final result = await _client
        .from('trips')
        .select('fare, commission')
        .eq('driver_id', driverId)
        .eq('status', 'completed')
        .gte('completed_at', startOfDay.toIso8601String());

    int total = 0;
    for (final trip in result) {
      final fare = trip['fare'] as int? ?? 0;
      final commission = trip['commission'] as int? ?? 0;
      total += fare - commission;
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> getDriverTrips(
    String driverId, {
    int limit = 50,
  }) async {
    return await _client
        .from('trips')
        .select('*, users!trips_passenger_id_fkey(name, photo_url)')
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<List<Map<String, dynamic>>> getPendingTrips({
    String? provinceId,
    String? category,
    String? driverId,
    int limit = 20,
  }) async {
    try {
      final tenMinutesAgo = DateTime.now().toUtc().subtract(const Duration(minutes: 10));
      var query = _client
          .from('trips')
          .select('*, users!trips_passenger_id_fkey(name, photo_url)')
          .eq('status', 'pending')
          .gte('created_at', tenMinutesAgo.toIso8601String());

      if (provinceId != null && provinceId.isNotEmpty) {
        query = query.eq('province_id', provinceId);
      }
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      // Exclusividade do chamado direto: enquanto a janela de outro
      // motorista estiver ativa, a viagem não aparece na fila partilhada.
      if (driverId != null && driverId.isNotEmpty) {
        final nowIso = DateTime.now().toUtc().toIso8601String();
        query = query.or(
          'direct_call_until.is.null,direct_call_until.lte.$nowIso,direct_call_driver.eq.$driverId',
        );
      }

      final result = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return result.where((t) => t['driver_id'] == null).toList();
    } catch (e) {
      debugPrint('Erro getPendingTrips: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDriverEarnings(String driverId) async {
    return await _client
        .from('trips')
        .select('id, fare, commission, distance, duration, category, created_at, completed_at, destination_name')
        .eq('driver_id', driverId)
        .eq('status', 'completed')
        .order('created_at', ascending: false)
        .limit(100);
  }

  Future<Map<String, dynamic>?> getDriverStats(String driverId) async {
    final trips = await _client
        .from('trips')
        .select('fare, commission, driver_rating')
        .eq('driver_id', driverId)
        .eq('status', 'completed');

    if (trips.isEmpty) {
      return {'total_trips': 0, 'total_earnings': 0, 'avg_rating': 0.0};
    }

    int totalEarnings = 0;
    double totalRating = 0;
    int ratedCount = 0;

    for (final trip in trips) {
      final fare = trip['fare'] as int? ?? 0;
      final commission = trip['commission'] as int? ?? 0;
      totalEarnings += fare - commission;

      final rating = trip['driver_rating'] as int?;
      if (rating != null) {
        totalRating += rating;
        ratedCount++;
      }
    }

    return {
      'total_trips': trips.length,
      'total_earnings': totalEarnings,
      'avg_rating': ratedCount > 0 ? totalRating / ratedCount : 0.0,
    };
  }
}
