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

  factory AdminActivityItem.fromTicket(Map<String, dynamic> row) {
    final name = ((row['users'] as Map?) ?? const {})['name'] as String?;
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
  }

  void _onSosChange(PostgresChangePayload payload) {
    final row = payload.newRecord;
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
