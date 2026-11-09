import 'package:supabase_flutter/supabase_flutter.dart';

/// Resumo de receitas devolvido por `admin_revenue_summary`.
///
/// Definições aprovadas (2026-11-09):
///   * empresa = comissão das corridas + assinaturas + pacotes de motoristas;
///   * motoristas = ganhos líquidos (tarifa − comissão + gorjeta);
///   * assinantes = subscrições ativas com pagamento confirmado;
///   * top-ups não entram como receita.
class RevenueSummary {
  const RevenueSummary({
    required this.start,
    required this.end,
    required this.trips,
    required this.drivers,
    required this.grossFares,
    required this.driverNet,
    required this.newSubscribers,
    required this.activeSubscribers,
    required this.subscriptionRevenue,
    required this.packagePurchases,
    required this.activePackages,
    required this.packageRevenue,
    required this.commission,
    required this.companyTotal,
  });

  final DateTime start;
  final DateTime end;

  /// Corridas concluídas no período e motoristas distintos que as fizeram.
  final int trips;
  final int drivers;

  /// Tarifas + gorjetas pagas pelos passageiros.
  final int grossFares;

  /// O que os motoristas efetivamente receberam.
  final int driverNet;

  /// Novos assinantes pagos no período e assinantes ativos no fim dele.
  final int newSubscribers;
  final int activeSubscribers;

  /// Receita de assinaturas de passageiros no período.
  final int subscriptionRevenue;

  /// Compras de pacotes de motoristas no período e pacotes ativos no fim.
  final int packagePurchases;
  final int activePackages;
  final int packageRevenue;

  /// Comissão das corridas no período (componente da receita da empresa).
  final int commission;

  /// Comissão + assinaturas + pacotes.
  final int companyTotal;

  int get companySubscriptions => subscriptionRevenue;
  int get companyPackages => packageRevenue;

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _date(Object? value, DateTime fallback) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? fallback;
  }

  factory RevenueSummary.fromJson(Map<String, dynamic> json) {
    final period = json['period'] is Map
        ? Map<String, dynamic>.from(json['period'] as Map)
        : const <String, dynamic>{};
    final trips = json['drivers'] is Map
        ? Map<String, dynamic>.from(json['drivers'] as Map)
        : const <String, dynamic>{};
    final subs = json['subscribers'] is Map
        ? Map<String, dynamic>.from(json['subscribers'] as Map)
        : const <String, dynamic>{};
    final packs = json['packages'] is Map
        ? Map<String, dynamic>.from(json['packages'] as Map)
        : const <String, dynamic>{};
    final company = json['company'] is Map
        ? Map<String, dynamic>.from(json['company'] as Map)
        : const <String, dynamic>{};

    final now = DateTime.now();
    return RevenueSummary(
      start: _date(period['start'], now),
      end: _date(period['end'], now),
      trips: _int(trips['trips']),
      drivers: _int(trips['drivers']),
      grossFares: _int(trips['gross_fares']),
      driverNet: _int(trips['driver_net']),
      newSubscribers: _int(subs['new']),
      activeSubscribers: _int(subs['active']),
      subscriptionRevenue: _int(subs['revenue']),
      packagePurchases: _int(packs['purchases']),
      activePackages: _int(packs['active']),
      packageRevenue: _int(packs['revenue']),
      commission: _int(company['commission']),
      companyTotal: _int(company['total']),
    );
  }
}

/// Acesso à RPC de receitas. A agregação é feita no servidor para não
/// descarregar viagens/subscrições para o browser.
class RevenueRepository {
  RevenueRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// `start`/`end` são inclusivos no início e exclusivos no fim.
  Future<RevenueSummary> summary({
    required DateTime start,
    required DateTime end,
  }) async {
    final res = await _client.rpc(
      'admin_revenue_summary',
      params: {
        'p_start': start.toUtc().toIso8601String(),
        'p_end': end.toUtc().toIso8601String(),
      },
    );
    if (res is Map<String, dynamic>) {
      return RevenueSummary.fromJson(res);
    }
    if (res is Map) {
      return RevenueSummary.fromJson(Map<String, dynamic>.from(res));
    }
    throw StateError('admin_revenue_summary devolveu um formato inesperado');
  }
}
