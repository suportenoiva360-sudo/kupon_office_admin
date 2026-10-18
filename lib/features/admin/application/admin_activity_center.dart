import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Um único evento de atividade para o admin ver: SOS, pedido de aprovação de
/// motorista ou ticket de suporte.
@immutable
class AdminActivityItem {
  final String id;
  final String kind; // 'sos' | 'approval' | 'ticket'
  final String title;
  final String subtitle;
  final DateTime at;
  final String route;

  const AdminActivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.route,
  });

  factory AdminActivityItem.fromSos(Map<String, dynamic> row) {
    // Eventos realtime trazem só as colunas cruas (sem o join `drivers`),
    // por isso o nome e o endereço podem faltar — usamos fallbacks.
    final driver = (row['drivers'] as Map?) ?? const {};
    final user = (driver['users'] as Map?) ?? const {};
    final name = user['name'] as String? ?? 'Motorista';
    final msg = (row['address'] as String? ?? '').replaceAll('\n', ' ');
    return AdminActivityItem(
      id: 'sos:${row['id']}',
      kind: 'sos',
      title: 'Sinal SOS — $name',
      subtitle: msg.isEmpty ? 'Emergência ativa' : msg,
      at: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      route: '/sos',
    );
  }

  factory AdminActivityItem.fromDriver(Map<String, dynamic> row) {
    final name = ((row['users'] as Map?) ?? const {})['name'] as String?;
    return AdminActivityItem(
      id: 'driver:${row['id']}',
      kind: 'approval',
      title: 'Novo motorista — ${name ?? 'por aprovar'}',
      subtitle: 'Documentos aguardam aprovação',
      at: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      route: '/motoristas',
    );
  }

  /// Novo utilizador (registo). O payload de realtime traz a linha de users.
factory AdminActivityItem.fromUser(Map<String, dynamic> row) {
  final name = row['name'] as String?;
  final role = row['role'] as String?;
  final roleLabel = role == 'driver' ? 'Motorista' : role == 'admin' ? 'Admin' : 'Passageiro';
  return AdminActivityItem(
    id: 'user:${row['id']}',
    kind: 'user',
    title: 'Nova conta — ${name ?? 'Sem nome'}',
    subtitle: 'Registo de $roleLabel',
    at: DateTime.tryParse(row['created_at'] as String? ?? '') ??
        DateTime.now(),
    route: '/usuarios',
  );
}

/// Nova corrida. O payload de trips traz nomes de pickup/destino.
factory AdminActivityItem.fromTrip(Map<String, dynamic> row) {
  final catLabels = {
    'moto': 'Moto',
    'car_standard': 'Standard',
    'car_comfort': 'Comfort',
    'car_luxury': 'Black',
  };
  final catLabel =
      catLabels[row['category']] ?? '${row['category'] ?? ''}'.replaceAll('_', ' ');
  final from = (row['pickup_name'] as String?) ?? 'origem';
  final to = (row['destination_name'] as String?) ?? 'destino';
  final fare = row['fare'];
  final fareTxt =
      (fare == null || '$fare' == 'null') ? '' : ' · Kz $fare';
  return AdminActivityItem(
    id: 'trip:${row['id']}',
    kind: 'trip',
    title: 'Nova corrida — $catLabel',
    subtitle: '$from → $to$fareTxt',
    at: DateTime.tryParse(row['created_at'] as String? ?? '') ??
        DateTime.now(),
    route: '/dashboard',
  );
}

/// Pedido de pagamento na carteira (recarga ou saque de passageiro).
factory AdminActivityItem.fromPayment(Map<String, dynamic> row) {
  final direction =
      row['direction'] == 'recarga' ? 'Pedido de recarga' : 'Pedido de saque';
  final methodTxt =
      '${row['method'] ?? ''}'.replaceAll('mobile_money', 'mobile money');
  return AdminActivityItem(
    id: 'payment:${row['id']}',
    kind: 'payment',
    title: '$direction — Kz ${row['amount'] ?? '?'}',
    subtitle: 'Método: $methodTxt',
    at: DateTime.tryParse(row['created_at'] as String? ?? '') ??
        DateTime.now(),
    route: '/financeiro',
  );
}

/// Pedido de saque de motorista.
factory AdminActivityItem.fromWithdrawal(Map<String, dynamic> row) {
  return AdminActivityItem(
    id: 'withdrawal:${row['id']}',
    kind: 'withdrawal',
    title: 'Saque de motorista — Kz ${row['amount'] ?? '?'}',
    subtitle:
        'Método: ${row['method'] ?? ''} · conta ${row['account'] ?? ''}',
    at: DateTime.tryParse(row['created_at'] as String? ?? '') ??
        DateTime.now(),
    route: '/financeiro',
  );
}

/// Nova resposta de utilizador num ticket de suporte.
factory AdminActivityItem.fromReply(Map<String, dynamic> row) {
  String msg = (row['message'] as String? ?? '').trim();
  if (msg.length > 60) msg = '${msg.substring(0, 57)}...';
  msg = msg.replaceAll('\n', ' ');
  return AdminActivityItem(
    id: 'reply:${row['id']}',
    kind: 'reply',
    title: 'Nova mensagem de suporte',
    subtitle: msg.isEmpty ? 'Ticket aberto tem resposta' : msg,
    at: DateTime.tryParse(row['created_at'] as String? ?? '') ??
        DateTime.now(),
    route: '/suporte',
  );
}

/// Versão com título/subtítulo substituídos (enriquecimento de nome).
AdminActivityItem withText({
  String? title,
  String? subtitle,
}) {
  return AdminActivityItem(
    id: id,
    kind: kind,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    at: at,
    route: route,
  );
}

factory AdminActivityItem.fromTicket(Map<String, dynamic> row) {    final name = ((row['users'] as Map?) ?? const {})['name'] as String?;
    return AdminActivityItem(
      id: 'ticket:${row['id']}',
      kind: 'ticket',
      title: 'Ticket de suporte aberto',
      subtitle: name ?? 'Utilizador',
      at: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      route: '/suporte',
    );
  }
}

/// Feed central de atividade do admin, em tempo real, mantido em memória
/// durante a sessão (sinal SOS + aprovações de motoristas + tickets abertos).
/// Subscreve uma única vez (`_initialized`) a 3 canais realtime; inserts entram
/// no feed, updates que resolvem o evento (SOS resolvido, motorista aprovado,
/// ticket fechado) saem dele. O estado "lido" vive apenas nesta instância —
/// sem backend novo, sem migrações, sem RPC (decisão fase 1).
class AdminActivityCenter extends ChangeNotifier {
  AdminActivityCenter._();

  static AdminActivityCenter? _instance;
  static AdminActivityCenter get instance =>
      _instance ??= AdminActivityCenter._();

  static const _limit = 200;
  final _client = Supabase.instance.client;
  final _channels = <RealtimeChannel>[];
  final List<AdminActivityItem> _items = [];
  final Set<String> _seenIds = {};

  bool _initialized = false;
  bool _loading = false;
  String? _error;

  bool get initialized => _initialized;
  bool get loading => _loading;

  /// Erro do último carregamento (null quando correu bem).
  String? get error => _error;
  List<AdminActivityItem> get items => List.unmodifiable(_items);
  List<AdminActivityItem> get unreadItems =>
      _items.where((e) => !_seenIds.contains(e.id)).toList();
  int get unreadCount => unreadItems.length;

  /// Chamado apenas quando chega atividade **nova** em tempo real (nunca no
  /// carregamento inicial), para a UI poder avisar o admin.
  void Function(AdminActivityItem item)? onActivity;

  /// Carrega o feed e liga as subscrições realtime (idempotente).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
    _setupRealtime();
  }

  /// Recarrega o feed: SOS ativos, motoristas por aprovar, tickets abertos.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    final failed = <String>[];
    await _loadSos(failed);
    await _loadDrivers(failed);
    await _loadTickets(failed);
    await _loadUsers(failed);
    await _loadTrips(failed);
    await _loadPayments(failed);
    await _loadWithdrawals(failed);
    await _loadReplies(failed);

    _loading = false;
    _error = failed.isEmpty
        ? null
        : 'Não foi possível carregar: ${failed.join(', ')}.';
    notifyListeners();
  }

  Future<void> _loadSos(List<String> failed) async {
    try {
      final rows = await _client
          .from('sos_alerts')
          .select('id,address,created_at,drivers(users(name))')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(_limit);
      for (final row in rows) {
        _add(AdminActivityItem.fromSos(row));
      }
    } catch (_) {
      failed.add('SOS');
    }
  }

  Future<void> _loadDrivers(List<String> failed) async {
    try {
      final rows = await _client
          .from('drivers')
          .select('id,users!inner(name),created_at')
          .eq('is_approved', false)
          // A conta admin não entra no feed — é apenas admin.
          .not('users.role', 'eq', 'admin')
          .order('created_at', ascending: false)
          .limit(_limit);
      for (final row in rows) {
        _add(AdminActivityItem.fromDriver(row));
      }
    } catch (_) {
      failed.add('aprovações');
    }
  }

  Future<void> _loadTickets(List<String> failed) async {
    try {
      final rows = await _client
          .from('support_tickets')
          .select('id,users!inner(name),created_at')
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(_limit);
      for (final row in rows) {
        _add(AdminActivityItem.fromTicket(row));
      }
    } catch (_) {
      failed.add('tickets');
    }
  }

  void _setupRealtime() {
    _channels.add(
      _client
          .channel('admin-center-sos')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sos_alerts',
            callback: _onSosChange,
          )
          .subscribe(),
    );
    _channels.add(
      _client
          .channel('admin-center-drivers')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'drivers',
            callback: _onDriverChange,
          )
          .subscribe(),
    );
    _channels.add(
      _client
          .channel('admin-center-tickets')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'support_tickets',
            callback: _onTicketChange,
          )
          .subscribe(),
    );
    // ---- Eventos "tudo o que acontece" ----
    _channels.add(
      _client
          .channel('admin-center-users')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'users',
            callback: (payload) =>
                _offer(AdminActivityItem.fromUser(payload.newRecord), live: true),
          )
          .subscribe(),
    );
    _channels.add(
      _client
          .channel('admin-center-trips')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'trips',
            callback: (payload) =>
                _offer(AdminActivityItem.fromTrip(payload.newRecord), live: true),
          )
          .subscribe(),
    );
    _channels.add(
      _client
          .channel('admin-center-payments')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'payment_requests',
            callback: (payload) {
              final item = AdminActivityItem.fromPayment(payload.newRecord);
              _offer(item, live: true);
              _enrichUserName('payment:${payload.newRecord['id']}',
                  '${payload.newRecord['user_id'] ?? ''}');
            },
          )
          .subscribe(),
    );
    _channels.add(
      _client
          .channel('admin-center-withdrawals')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'withdrawals',
            callback: (payload) {
              final item =
                  AdminActivityItem.fromWithdrawal(payload.newRecord);
              _offer(item, live: true);
              _enrichDriverName('withdrawal:${payload.newRecord['id']}',
                  '${payload.newRecord['driver_id'] ?? ''}');
            },
          )
          .subscribe(),
    );
    _channels.add(
      _client
          .channel('admin-center-replies')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'support_replies',
            callback: (payload) =>
                _offer(AdminActivityItem.fromReply(payload.newRecord), live: true),
          )
          .subscribe(),
    );
  }

  /// Backlog: contas registadas nas últimas 24 h (feed abre com contexto).
  Future<void> _loadUsers(List<String> failed) async {
    try {
      final since =
          DateTime.now().toUtc().subtract(const Duration(hours: 24));
      final rows = await _client
          .from('users')
          .select('id,name,role,created_at')
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: false)
          .limit(20);
      for (final row in rows) {
        _add(AdminActivityItem.fromUser(Map<String, dynamic>.from(row)));
      }
    } catch (_) {
      failed.add('contas');
    }
  }

  /// Backlog: corridas de hoje.
  Future<void> _loadTrips(List<String> failed) async {
    try {
      final since = DateTime.now().toUtc().subtract(const Duration(hours: 24));
      final rows = await _client
          .from('trips')
          .select('id,category,pickup_name,destination_name,fare,created_at'
              ',status')
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: false)
          .limit(20);
      for (final row in rows) {
        _add(AdminActivityItem.fromTrip(Map<String, dynamic>.from(row)));
      }
    } catch (_) {
      failed.add('corridas');
    }
  }

  /// Backlog: pedidos de pagamento ainda pendentes.
  Future<void> _loadPayments(List<String> failed) async {
    try {
      final rows = await _client
          .from('payment_requests')
          .select('id,user_id,direction,amount,method,created_at')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);
      for (final row in rows) {
        final item =
            AdminActivityItem.fromPayment(Map<String, dynamic>.from(row));
        _add(item);
      }
    } catch (_) {
      failed.add('pagamentos');
    }
  }

  /// Backlog: saques de motorista ainda pendentes.
  Future<void> _loadWithdrawals(List<String> failed) async {
    try {
      final rows = await _client
          .from('withdrawals')
          .select('id,driver_id,amount,method,account,created_at')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);
      for (final row in rows) {
        _add(AdminActivityItem.fromWithdrawal(Map<String, dynamic>.from(row)));
      }
    } catch (_) {
      failed.add('saques');
    }
  }

  /// Backlog: respostas de suporte da última hora.
  Future<void> _loadReplies(List<String> failed) async {
    try {
      final since =
          DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final rows = await _client
          .from('support_replies')
          .select('id,ticket_id,sender_id,message,created_at')
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: false)
          .limit(10);
      for (final row in rows) {
        _add(AdminActivityItem.fromReply(Map<String, dynamic>.from(row)));
      }
    } catch (_) {
      failed.add('respostas');
    }
  }

  /// Depois do realtime chegar, resolve o NOME do utilizador (a linha cru
  /// não tem join) e actualiza o item no feed.
  Future<void> _enrichUserName(String itemId, String userId) async {
    if (userId.isEmpty) return;
    try {
      final row = await _client
          .from('users')
          .select('name')
          .eq('id', userId)
          .maybeSingle();
      final name = row?['name'] as String?;
      if (name == null || name.isEmpty) return;
      final idx = _items.indexWhere((e) => e.id == itemId);
      if (idx < 0) return;
      final old = _items[idx];
      _items[idx] = old.withText(
        title: '${old.title.split('—').first.trim()} — $name',
        subtitle: '${old.subtitle} · $name',
      );
      notifyListeners();
    } catch (_) {}
  }

  /// Idem para motorista (withdrawals.driver_id é id de `drivers`).
  Future<void> _enrichDriverName(String itemId, String driverId) async {
    if (driverId.isEmpty || driverId == 'null') return;
    try {
      final row = await _client
          .from('drivers')
          .select('id,users(name)')
          .eq('id', driverId)
          .maybeSingle();
      final name = ((row?['users'] as Map?) ?? const {})['name'] as String?;
      if (name == null || name.isEmpty) return;
      final idx = _items.indexWhere((e) => e.id == itemId);
      if (idx < 0) return;
      final old = _items[idx];
      _items[idx] = old.withText(
        title: '${old.title.split('—').first.trim()} — $name',
        subtitle: '${old.subtitle} · $name',
      );
      notifyListeners();
    } catch (_) {}
  }

  void _onSosChange(PostgresChangePayload payload) {    final row = payload.newRecord;
    final id = 'sos:${row['id']}';
    if (payload.eventType == PostgresChangeEvent.delete ||
        row['status'] != 'active') {
      _remove(id);
      return;
    }
    _offer(AdminActivityItem.fromSos(row), live: true);
  }

  void _onDriverChange(PostgresChangePayload payload) {
    final row = payload.newRecord;
    // Realtime não tras o join — consulta o papel do utilizador e ignora
    // registos da conta admin (admins só são admins).
    final userId = row['user_id']?.toString() ?? '';
    if (userId.isNotEmpty) {
      _client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle()
          .then((u) {
        if (u?['role'] == 'admin') {
          _remove('driver:${row['id']}');
        }
      });
    }
    final id = 'driver:${row['id']}';
    if (row['is_approved'] == true) {
      _remove(id);
      return;
    }
    if (row['is_approved'] == false) {
      _offer(AdminActivityItem.fromDriver(row), live: true);
    }
  }

  void _onTicketChange(PostgresChangePayload payload) {
    final row = payload.newRecord;
    final id = 'ticket:${row['id']}';
    if (row['status'] != 'open') {
      _remove(id);
      return;
    }
    _offer(AdminActivityItem.fromTicket(row), live: true);
  }

  /// Insere mantendo a lista ordenada por data (mais recente primeiro).
  void _insertSorted(AdminActivityItem item) {
    final index = _items.indexWhere((e) => e.at.isBefore(item.at));
    if (index < 0) {
      _items.add(item);
    } else {
      _items.insert(index, item);
    }
    if (_items.length > _limit) _items.removeRange(_limit, _items.length);
  }

  void _add(AdminActivityItem item) {
    if (_items.any((e) => e.id == item.id)) return;
    _insertSorted(item);
  }

  void _offer(AdminActivityItem item, {bool live = false}) {
    if (_items.any((e) => e.id == item.id)) return;
    _insertSorted(item);
    if (live) onActivity?.call(item);
    notifyListeners();
  }

  void _remove(String id) {
    final before = _items.length;
    _items.removeWhere((e) => e.id == id);
    _seenIds.remove(id);
    if (_items.length != before) notifyListeners();
  }

  /// Marca um item como visto (badge continua a contar os restantes).
  void markSeen(String id) {
    if (_seenIds.add(id)) notifyListeners();
  }

  void markAllRead() {
    final before = _seenIds.length;
    _seenIds.addAll(_items.map((e) => e.id).toSet());
    if (_seenIds.length != before) notifyListeners();
  }

  @override
  void dispose() {
    for (final c in _channels) {
      c.unsubscribe();
    }
    _channels.clear();
    _instance = null;
    super.dispose();
  }
}
