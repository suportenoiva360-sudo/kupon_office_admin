import 'package:supabase_flutter/supabase_flutter.dart';

/// Formata um número com separador de milhar (padrão pt-AO).
///
/// Ex.: 1284590 → "1.284.590"
String formatNumber(num value) {
  final s = value.truncate().toString();
  final neg = s.startsWith('-');
  final digits = neg ? s.substring(1) : s;
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buf.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buf.write('.');
  }
  return '${neg ? '-' : ''}$buf';
}

/// Ponto diário do gráfico "Corridas vs Receita".
class DailyPoint {
  final DateTime date;
  final int trips;
  final int revenue;

  const DailyPoint({
    required this.date,
    required this.trips,
    required this.revenue,
  });
}

/// Alerta apresentado na secção "Alertas Recentes".
class DashAlert {
  final String kind;
  final String title;
  final String description;
  final String time;
  final DateTime? at;
  final String route;

  const DashAlert({
    required this.kind,
    required this.title,
    required this.description,
    required this.time,
    required this.at,
    required this.route,
  });
}

/// Snapshot completo dos KPI / gráfico / alertas / ranking da página inicial.
class DashboardSnapshot {
  final int revenue30d;
  final int prevRevenue30d;
  final int trips24h;
  final int prevTrips24h;
  final int onlineDrivers;
  final int approvedDrivers;
  final int activeUsers;
  final int newUsers30d;
  final int prevNewUsers30d;
  final int pendingDrivers;
  final int openTickets;
  final List<DailyPoint> daily;
  final List<DashAlert> alerts;
  final List<Map<String, dynamic>> topDrivers;
  final bool hadFailures;

  const DashboardSnapshot({
    required this.revenue30d,
    required this.prevRevenue30d,
    required this.trips24h,
    required this.prevTrips24h,
    required this.onlineDrivers,
    required this.approvedDrivers,
    required this.activeUsers,
    required this.newUsers30d,
    required this.prevNewUsers30d,
    required this.pendingDrivers,
    required this.openTickets,
    required this.daily,
    required this.alerts,
    required this.topDrivers,
    this.hadFailures = false,
  });
}

class DashboardRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<DashboardSnapshot> getSnapshot({
    DateTime? start,
    DateTime? end,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rangeStart =
        start ?? today.subtract(const Duration(days: 30));
    final rangeEnd = end ?? now;

    final duration = rangeEnd.difference(rangeStart);
    final prevStart = rangeStart.subtract(duration);
    final prevEnd = rangeStart;
    final daysInPeriod =
        (rangeEnd.difference(rangeStart).inDays + 1).clamp(1, 90);

    var failedCount = 0;
    Future<T> safe<T>(Future<T> Function() fn, T fallback) async {
      try {
        return await fn();
      } catch (_) {
        failedCount++;
        return fallback;
      }
    }

    final results = await Future.wait<Object?>([
      safe(() => getRevenue(
            start: rangeStart,
            end: rangeEnd,
          ), 0),
      safe(() => getRevenue(
            start: prevStart,
            end: prevEnd,
          ), 0),
      safe(() => getTripsCount(
            start: rangeStart,
            end: rangeEnd,
          ), 0),
      safe(() => getTripsCount(
            start: prevStart,
            end: prevEnd,
          ), 0),
      safe(getOnlineDrivers, 0),
      safe(getApprovedDrivers, 0),
      safe(getActiveUsers, 0),
      safe(() => getNewUsers(
            start: rangeStart,
            end: rangeEnd,
          ), 0),
      safe(() => getNewUsers(
            start: prevStart,
            end: prevEnd,
          ), 0),
      safe(getPendingDriversCount, 0),
      safe(getOpenTickets, 0),
      safe(
        () => getDailyChart(
          daysInPeriod,
          customStart: rangeStart,
          customEnd: rangeEnd,
        ),
        <DailyPoint>[],
      ),
      safe(getAlerts, <DashAlert>[]),
      safe(getTopDrivers, <Map<String, dynamic>>[]),
    ]);

    return DashboardSnapshot(
      revenue30d: results[0] as int,
      prevRevenue30d: results[1] as int,
      trips24h: results[2] as int,
      prevTrips24h: results[3] as int,
      onlineDrivers: results[4] as int,
      approvedDrivers: results[5] as int,
      activeUsers: results[6] as int,
      newUsers30d: results[7] as int,
      prevNewUsers30d: results[8] as int,
      pendingDrivers: results[9] as int,
      openTickets: results[10] as int,
      daily: results[11] as List<DailyPoint>,
      alerts: results[12] as List<DashAlert>,
      topDrivers: results[13] as List<Map<String, dynamic>>,
      hadFailures: failedCount > 0,
    );
  }

  /// Soma das fares das viagens concluídas dentro do intervalo.
  Future<int> getRevenue({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _client
        .from('trips')
        .select('fare')
        .eq('status', 'completed')
        .gte('completed_at', start.toUtc().toIso8601String())
        .lte('completed_at', end.toUtc().toIso8601String());
    return rows.fold<int>(
      0,
      (sum, r) => sum + ((r['fare'] as num?)?.toInt() ?? 0),
    );
  }

  /// Contagem de viagens criadas no intervalo (inclusivo de `end`).
  Future<int> getTripsCount({
    required DateTime start,
    DateTime? end,
  }) async {
    var query = _client
        .from('trips')
        .select('id')
        .gte('created_at', start.toUtc().toIso8601String());
    if (end != null) {
      query = query.lte('created_at', end.toUtc().toIso8601String());
    }
    return (await query).length;
  }

  Future<int> getOnlineDrivers() async {
    final rows = await _client
        .from('drivers')
        .select('id')
        .eq('is_online', true)
        .eq('is_approved', true)
        .eq('is_blocked', false);
    return rows.length;
  }

  Future<int> getApprovedDrivers() async {
    final rows = await _client
        .from('drivers')
        .select('id')
        .eq('is_approved', true)
        .eq('is_blocked', false);
    return rows.length;
  }

  Future<int> getActiveUsers() async {
    return (await _client.from('users').select('id')).length;
  }

  /// Novos registos (perfil) no intervalo. Defensivo: sem `created_at`
  /// na tabela, devolve 0 em vez de derrubar o dashboard.
  Future<int> getNewUsers({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final rows = await _client
          .from('users')
          .select('id')
          .gte('created_at', start.toUtc().toIso8601String())
          .lte('created_at', end.toUtc().toIso8601String());
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getPendingDriversCount() async {
    final rows = await _client
        .from('drivers')
        .select('id')
        .eq('is_approved', false)
        .eq('is_blocked', false);
    return rows.length;
  }

  Future<int> getOpenTickets() async {
    final rows = await _client
        .from('support_tickets')
        .select('id')
        .eq('status', 'open');
    return rows.length;
  }

  /// Viagens dos últimos `days` dias, agregadas por dia local:
  /// [DailyPoint.trips] por `created_at` e [DailyPoint.revenue] por `completed_at`.
  Future<List<DailyPoint>> getDailyChart(
    int days, {
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final now = customEnd ?? DateTime.now();
    final startOfEnd = DateTime(now.year, now.month, now.day);
    final start = customStart != null
        ? DateTime(customStart.year, customStart.month, customStart.day)
        : startOfEnd.subtract(Duration(days: (days - 1).clamp(0, 365)));

    final numDays = (startOfEnd.difference(start).inDays + 1).clamp(1, 90);

    final trips = await _client
        .from('trips')
        .select('fare, created_at, completed_at')
        .gte('created_at', start.toUtc().toIso8601String())
        .lte('created_at', now.toUtc().toIso8601String());

    final counts = <DateTime, int>{};
    final revenue = <DateTime, int>{};
    for (final t in trips) {
      final created = DateTime.tryParse(t['created_at'] as String? ?? '');
      if (created != null) {
        final d = _localDay(created);
        if (!d.isBefore(start) && !d.isAfter(startOfEnd)) {
          counts[d] = (counts[d] ?? 0) + 1;
        }
      }
      final completed = DateTime.tryParse(t['completed_at'] as String? ?? '');
      if (completed != null) {
        final d = _localDay(completed);
        if (!d.isBefore(start) && !d.isAfter(startOfEnd)) {
          revenue[d] = (revenue[d] ?? 0) + ((t['fare'] as num?)?.toInt() ?? 0);
        }
      }
    }

    return List.generate(numDays, (i) {
      final day = start.add(Duration(days: i));
      return DailyPoint(
        date: day,
        trips: counts[day] ?? 0,
        revenue: revenue[day] ?? 0,
      );
    });
  }

  /// Alertas recentes reais: aprovações pendentes, saques pendentes,
  /// SOS ativos e tickets de suporte abertos — ordenados por recência.
  Future<List<DashAlert>> getAlerts() async {
    final alerts = <DashAlert>[];

    try {
      final approvals = await _client
          .from('drivers')
          .select('id, category, created_at, users!inner(name, photo_url)')
          .eq('is_approved', false)
          .order('created_at', ascending: false)
          .limit(4);
      for (final d in approvals) {
        final user = (d['users'] as Map?) ?? {};
        final name = user['name'] as String? ?? 'Novo Motorista';
        alerts.add(DashAlert(
          kind: 'approval',
          title: 'Novo Registo de Motorista',
          description: '$name registado para aprovação.',
          time: _relativeTime(_parseAt(d['created_at'])),
          at: _parseAt(d['created_at']),
          route: '/motoristas',
        ));
      }
    } catch (_) {}

    try {
      final sos = await _client
          .from('sos_alerts')
          .select('id, created_at, address')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(3);
      for (final s in sos) {
        final addr = s['address'] as String?;
        alerts.add(DashAlert(
          kind: 'sos',
          title: 'Sinal SOS de Emergência',
          description: addr != null && addr.isNotEmpty
              ? 'Alerta SOS ativo — $addr.'
              : 'Alerta SOS ativo — requer ação da equipa.',
          time: _relativeTime(_parseAt(s['created_at'])),
          at: _parseAt(s['created_at']),
          route: '/sos',
        ));
      }
    } catch (_) {}

    try {
      final tickets = await _client
          .from('support_tickets')
          .select('id, subject, created_at, users!inner(name, photo_url)')
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(3);
      for (final t in tickets) {
        final user = (t['users'] as Map?) ?? {};
        final name = user['name'] as String? ?? 'Utilizador';
        final subject = t['subject'] as String?;
        alerts.add(DashAlert(
          kind: 'ticket',
          title: 'Ticket de Suporte Aberto',
          description: subject != null && subject.isNotEmpty
              ? '$subject (por $name)'
              : 'Ticket aberto por $name.',
          time: _relativeTime(_parseAt(t['created_at'])),
          at: _parseAt(t['created_at']),
          route: '/suporte',
        ));
      }
    } catch (_) {}

    alerts.sort(
      (a, b) => (b.at ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.at ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return alerts;
  }

  /// Top motoristas aprovados por total de viagens.
  Future<List<Map<String, dynamic>>> getTopDrivers({int limit = 5}) async {
    return await _client
        .from('drivers')
        .select('id, total_trips, rating, users!inner(name, photo_url)')
        .eq('is_approved', true)
        .eq('is_blocked', false)
        .order('total_trips', ascending: false)
        .limit(limit);
  }

  /// Ranking de motoristas por período: conta corridas, soma receita,
  /// calcula rating médio e overall rating dentro da janela temporal.
  Future<List<Map<String, dynamic>>> getLeaderboardByPeriod({
    required DateTime start,
    required DateTime end,
    String? category,
    int limit = 20,
  }) async {
    // 1. Buscar motoristas aprovados
    var driverQuery = _client
        .from('drivers')
        .select('id, rating, category, is_approved, is_blocked, users!inner(name, photo_url)')
        .eq('is_approved', true)
        .eq('is_blocked', false);

    if (category != null && category != 'all') {
      driverQuery = driverQuery.eq('category', category);
    }

    final drivers = await driverQuery;
    if (drivers.isEmpty) return [];

    final driverIds = <String>[];
    final driverMap = <String, Map<String, dynamic>>{};
    for (final d in drivers) {
      final id = d['id'] as String;
      driverIds.add(id);
      final user = (d['users'] as Map?) ?? {};
      driverMap[id] = {
        'driver_id': id,
        'name': user['name'] as String? ?? 'Motorista',
        'photo_url': user['photo_url'] as String? ?? '',
        'category': d['category'] as String?,
        'rating': (d['rating'] as num?)?.toDouble() ?? 0.0,
        'period_trips': 0,
        'period_revenue': 0,
      };
    }

    // 2. Buscar trips completadas no período (paginado, máx 1000)
    final trips = await _client
        .from('trips')
        .select('driver_id, fare')
        .eq('status', 'completed')
        .gte('completed_at', start.toUtc().toIso8601String())
        .lte('completed_at', end.toUtc().toIso8601String())
        .inFilter('driver_id', driverIds)
        .limit(1000);

    // 3. Agregar
    for (final t in trips) {
      final driverId = t['driver_id'] as String?;
      if (driverId == null || !driverMap.containsKey(driverId)) continue;
      final fare = (t['fare'] as num?)?.toInt() ?? 0;
      driverMap[driverId]!['period_trips'] = (driverMap[driverId]!['period_trips'] as int) + 1;
      driverMap[driverId]!['period_revenue'] = (driverMap[driverId]!['period_revenue'] as int) + fare;
    }

    final list = driverMap.values.where((d) => (d['period_trips'] as int) > 0).toList();
    list.sort((a, b) => (b['period_trips'] as int).compareTo(a['period_trips'] as int));
    return list.take(limit).toList();
  }

  static DateTime _localDay(DateTime utc) {
    final l = utc.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  static DateTime? _parseAt(Object? value) {
    return DateTime.tryParse(value as String? ?? '');
  }

  static String _relativeTime(DateTime? at) {
    if (at == null) return 'Agora mesmo';
    final diff = DateTime.now().difference(at.toLocal());
    if (diff.inMinutes < 1) return 'Agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return 'há ${diff.inDays}d';
  }
}