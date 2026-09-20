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
    final name = row['driver_name'] as String? ?? 'Motorista';
    final msg = (row['message'] as String? ?? '').replaceAll('\n', ' ');
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
/// Subscreve uma única vez (`_initialized`) a 3 canais realtime e mantém uma
/// lista limitada + contagem de não-lidos. O estado "lido" vive apenas nesta
/// instância — sem backend novo, sem migrações, sem RPC (decisão fase 1).
class AdminActivityCenter extends ChangeNotifier {
  AdminActivityCenter._();

  static AdminActivityCenter? _instance;
  static AdminActivityCenter get instance =>
      _instance ??= AdminActivityCenter._();

  static const _limit = 401;
  final _client = Supabase.instance.client;
  final _channels = <RealtimeChannel>[];
  final List<AdminActivityItem> _items = [];
  final Set<String> _seenIds = {};
  Timer? _refreshDebounce;

  bool _initialized = false;
  int _unread = 0;
  bool get initialized => _initialized;
  List<AdminActivityItem> get items => List.unmodifiable(_items);
  List<AdminActivityItem> get unreadItems =>
      _items.where((e) => !_seenIds.contains(e.id)).toList();
  int get unread => _seenIds.isEmpty ? _unread : _unread;

  void Function(String message)? onActivity;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadInitial();
    _setupRealtime();
  }

  Future<void> _loadInitial() async {
    try {
      final sos = await _client
          .from('sos_alerts')
          .select('id,driver_name,message,created_at')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(_limit);
      for (final it in sos) {
        _offer(AdminActivityItem.fromSos(it));
      }
    } catch (_) {}
    try {
      final drivers = await _client
          .from('drivers')
          .select('id,users!inner(name),created_at')
          .eq('is_approved', false)
          .order('created_at', ascending: false)
          .limit(_limit);
      for (final it in drivers) {
        _offer(AdminActivityItem.fromDriver(it));
      }
    } catch (_) {}
    try {
      final tickets = await _client
          .from('support_tickets')
          .select('id,users!inner(name),created_at')
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(_limit);
      for (final it in tickets) {
        _offer(AdminActivityItem.fromTicket(it));
      }
    } catch (_) {}
    notifyListeners();
  }

  void _setupRealtime() {
    _channels.add(
      _client
          .channel('admin-center-sos')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'sos_alerts',
            callback: (payload) => _offerSos(payload.newRecord),
          )
          .subscribe(),
    );
    _channels.add(
      _client
          .channel('admin-center-drivers')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'drivers',
            callback: (payload) => _offerDriver(payload.newRecord),
          )
          .subscribe(),
    );
    _channels.add(
      _client
          .channel('admin-center-tickets')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'support_tickets',
            callback: (payload) => _offerTicket(payload.newRecord),
          )
          .subscribe(),
    );
  }

  void _offerSos(Map<String, dynamic> row) {
    if (row['status'] == 'active') {
      _offer(AdminActivityItem.fromSos(row));
    }
  }

  void _offerDriver(Map<String, dynamic> row) {
    if (row['is_approved'] == false) {
      _offer(AdminActivityItem.fromDriver(row));
    }
  }

  void _offerTicket(Map<String, dynamic> row) {
    if (row['status'] == 'open') {
      _offer(AdminActivityItem.fromTicket(row));
    }
  }

  void _offer(AdminActivityItem item) {
    final exists = _items.any((e) => e.id == item.id);
    if (exists) return;
    _items.insert(0, item);
    if (_items.length > _limit) _items.removeRange(_limit, _items.length);
    _unread++;
    onActivity?.call(item.title);
    notifyListeners();
  }

  void markSeen(String id) => _seenIds.add(id);

  void markAllRead() => _seenIds.addAll(_items.map((e) => e.id).toSet());

  @override
  void dispose() {
    for (final c in _channels) {
      c.unsubscribe();
    }
    _refreshDebounce?.cancel();
    _instance = null;
    super.dispose();
  }
}
