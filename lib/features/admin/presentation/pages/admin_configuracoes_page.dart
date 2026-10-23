import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminConfiguracoesPage extends StatefulWidget {
  const AdminConfiguracoesPage({super.key});

  @override
  State<AdminConfiguracoesPage> createState() => _AdminConfiguracoesPageState();
}

class _AdminConfiguracoesPageState extends State<AdminConfiguracoesPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  bool _loaded = false;

  final _fares = <String, Map<String, TextEditingController>>{};
  // Recompensa por convite (kupon_settings.referral_reward_amount, Kz).
  final TextEditingController _referralRewardCtrl = TextEditingController();
  // 2.4 — aviso sonoro de fim de viagem (kupon_settings).
  final TextEditingController _rideEndAnnounceCtrl = TextEditingController();
  final TextEditingController _rideEndRadiusCtrl = TextEditingController();
  // [2.5] finos da cadeia (kupon_settings).
  final TextEditingController _chainRadiusCtrl = TextEditingController();
  final TextEditingController _chainAgeCtrl = TextEditingController();
  final TextEditingController _chainWindowCtrl = TextEditingController();
  // Cancelamentos [fase 4] — faixas + atrasos + revisão/contestação.
  final TextEditingController _capFee1Ctrl = TextEditingController();
  final TextEditingController _capFee2Ctrl = TextEditingController();
  final TextEditingController _capFee3Ctrl = TextEditingController();
  final TextEditingController _capFee4Ctrl = TextEditingController();
  final TextEditingController _capWarnMinCtrl = TextEditingController();
  final TextEditingController _capFreeMinCtrl = TextEditingController();
  final TextEditingController _capStallMinCtrl = TextEditingController();
  final TextEditingController _capRevThreshCtrl = TextEditingController();
  final TextEditingController _capDisputeDaysCtrl = TextEditingController();
  // Última alteração de cada categoria (tariffs.updated_at).
  final _tariffUpdatedAt = <String, DateTime?>{};
  // id(uuid) de cada tarifa — mapeia row_key do histórico -> categoria.
  final _tariffIds = <String, String>{};
  // Histórico de auditoria (config_change_log) — últimas alterações gerais.
  List<Map<String, dynamic>> _history = [];

  static const _categories = [
    'moto',
    'car_standard',
    'car_comfort',
    'car_luxury',
  ];

  static const _fareFields = [
    ('base', 'TARIFA BASE (Kz)', Icons.flag_rounded),
    ('per_km', 'VALOR POR KM (Kz)', Icons.straighten_rounded),
    ('per_min', 'VALOR POR MIN (Kz)', Icons.timer_outlined),
    ('minimum_fare', 'TARIFA MÍNIMA (Kz)', Icons.low_priority_rounded),
    ('commission', 'COMISSÃO (%)', Icons.percent_rounded),
  ];

  // Janelas de demanda: grupo de 5 campos por janela
  // [name, start_hour, end_hour, multiplier, id]
  final List<TextEditingController> _windowFields = [];

  @override
  void initState() {
    super.initState();
    for (final cat in _categories) {
      _fares[cat] = {
        for (final (field, _, _) in _fareFields) field: TextEditingController(),
      };
    }
    _loadSettings();
  }

  @override
  void dispose() {
    for (final map in _fares.values) {
      for (final ctrl in map.values) {
        ctrl.dispose();
      }
    }
    for (final ctrl in _windowFields) {
      ctrl.dispose();
    }
    _referralRewardCtrl.dispose();
    _rideEndAnnounceCtrl.dispose();
    _rideEndRadiusCtrl.dispose();
    _chainRadiusCtrl.dispose();
    _chainAgeCtrl.dispose();
    _chainWindowCtrl.dispose();
    _rideEndRadiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final tariffRows = await _db
          .from('tariffs')
          .select(
            'id,category,base_fare,per_km,per_minute,minimum_fare'
            ',commission_percentage,is_active,updated_at',
          )
          .order('category');

      // Recompensa por convite (kupon_settings).
      try {
        final setting = await _db
            .from('kupon_settings')
            .select('value')
            .eq('key', 'referral_reward_amount')
            .maybeSingle();
        if (setting != null) {
          _referralRewardCtrl.text = '${setting['value'] ?? '500'}';
        } else {
          _referralRewardCtrl.text = '500';
        }
      } catch (_) {
        _referralRewardCtrl.text = '500';
      }

      // 2.4 — aviso sonoro de fim de viagem.
      try {
        final rows = await _db
            .from('kupon_settings')
            .select('key, value')
            .inFilter('key', [
              'ride_end_announcement',
              'ride_end_announce_distance_m',
            ]);
        String msg =
            'Caro KupaKamba, antes de sair, garanta que não deixou '
            'nenhum pertence no veículo. Obrigado por escolher a KupON!';
        String radius = '600';
        for (final row in (rows as List)) {
          final key = row['key'] as String?;
          final value = row['value'];
          if (key == 'ride_end_announcement') {
            if (value != null) msg = '$value';
          } else if (key == 'ride_end_announce_distance_m') {
            radius = '$value'.trim();
          }
        }
        _rideEndAnnounceCtrl.text = msg;
        _rideEndRadiusCtrl.text = radius;
      } catch (_) {}

      // [2.5] finos da cadeia (defaults = valores em produção).
      try {
        final chainRows = await _db
            .from('kupon_settings')
            .select('key, value')
            .inFilter('key', [
              'chain_max_pickup_km',
              'chain_max_trip_age_min',
              'chain_reserve_seconds',
            ]);
        String km = '3';
        String ageMin = '10';
        String windowS = '90';
        for (final row in (chainRows as List)) {
          final key = row['key'] as String?;
          final value = row['value'];
          final txt = value == null ? '' : '$value'.trim();
          switch (key) {
            case 'chain_max_pickup_km':
              if (txt.isNotEmpty) km = txt;
            case 'chain_max_trip_age_min':
              if (txt.isNotEmpty) ageMin = txt;
            case 'chain_reserve_seconds':
              if (txt.isNotEmpty) windowS = txt;
          }
        }
        _chainRadiusCtrl.text = km;
        _chainAgeCtrl.text = ageMin;
        _chainWindowCtrl.text = windowS;
      } catch (_) {
        _chainRadiusCtrl.text = '3';
        _chainAgeCtrl.text = '10';
        _chainWindowCtrl.text = '90';
      }

      // Cancelamentos [fase 4] — faixas de taxa + atrasos + revisão/contestação
      try {
        final capRows = await _db
            .from('kupon_settings')
            .select('key, value')
            .inFilter('key', [
              'cancel_fee_bands',
              'cancel_delay_warn_min',
              'cancel_delay_free_min',
              'cancel_stall_min',
              'cancel_debt_review_threshold',
              'cancel_dispute_paid_window_days',
            ]);
        List fees = const [0, 100, 200, 300];
        String warn = '5', free = '10', stall = '3', rev = '3', days = '7';
        for (final row in (capRows as List)) {
          final key = row['key'] as String?;
          final value = row['value'];
          final txt = value == null ? '' : '$value'.trim();
          switch (key) {
            case 'cancel_fee_bands':
              if (value is List && value.isNotEmpty) fees = value;
            case 'cancel_delay_warn_min':
              if (txt.isNotEmpty) warn = txt;
            case 'cancel_delay_free_min':
              if (txt.isNotEmpty) free = txt;
            case 'cancel_stall_min':
              if (txt.isNotEmpty) stall = txt;
            case 'cancel_debt_review_threshold':
              if (txt.isNotEmpty) rev = txt;
            case 'cancel_dispute_paid_window_days':
              if (txt.isNotEmpty) days = txt;
          }
        }
        // bands [[taxa, kmMax], ...] — kmMax 1/3/5/null
        String bandFee(int i) {
          if (fees.length > i) {
            final b = fees[i];
            if (b is List && b.isNotEmpty) {
              return '${b[0] ?? 0}'.trim();
            }
            return '$b'.trim();
          }
          return '0';
        }

        setState(() {
          _capFee1Ctrl.text = bandFee(0);
          _capFee2Ctrl.text = bandFee(1);
          _capFee3Ctrl.text = bandFee(2);
          _capFee4Ctrl.text = bandFee(3);
          _capWarnMinCtrl.text = warn;
          _capFreeMinCtrl.text = free;
          _capStallMinCtrl.text = stall;
          _capRevThreshCtrl.text = rev;
          _capDisputeDaysCtrl.text = days;
        });
      } catch (_) {}

      for (final row in (tariffRows as List)) {
        final cat = row['category'] as String?;
        if (cat == null || !_fares.containsKey(cat)) continue;
        if (row['is_active'] != true) continue;
        _tariffIds[cat] = '${row['id'] ?? ''}';
        _tariffUpdatedAt[cat] = DateTime.tryParse('${row['updated_at'] ?? ''}');
        _fares[cat]!['base']!.text = '${row['base_fare'] ?? ''}';
        _fares[cat]!['per_km']!.text = '${row['per_km'] ?? ''}';
        _fares[cat]!['per_min']!.text = '${row['per_minute'] ?? ''}';
        _fares[cat]!['minimum_fare']!.text = '${row['minimum_fare'] ?? ''}';
        _fares[cat]!['commission']!.text =
            '${row['commission_percentage'] ?? ''}';
      }

      final windowRows = await _db
          .from('peak_windows')
          .select('id,name,start_hour,end_hour,multiplier,kind')
          .eq('is_active', true)
          .order('kind')
          .order('start_hour');

      for (final ctrl in _windowFields) {
        ctrl.dispose();
      }
      _windowFields.clear();
      for (final row in (windowRows as List)) {
        _windowFields.addAll([
          TextEditingController(text: '${row['name'] ?? ''}'),
          TextEditingController(text: '${row['start_hour'] ?? ''}'),
          TextEditingController(text: '${row['end_hour'] ?? ''}'),
          TextEditingController(text: '${row['multiplier'] ?? ''}'),
          TextEditingController(text: '${row['id'] ?? ''}'),
        ]);
      }
      _loaded = true;
      await _loadHistory();
    } catch (_) {
      _loaded = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível carregar as tarifas. Atualiza bloqueado para '
              'evitar apagar os valores atuais.',
            ),
            backgroundColor: Color(0xFFCF6679),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_loaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'As tarifas ainda não foram carregadas — não é possível '
              'guardar. Atualize a página e tente novamente.',
            ),
            backgroundColor: Color(0xFFCF6679),
          ),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      // PATCH sem linhas devolve "sucesso" — se o RLS bloquear a escrita o
      // Supabase não erro. Pedimos representation para PODER contar e avisar.
      final failure = <String>[];

      for (final cat in _categories) {
        final rows = await _db
            .from('tariffs')
            .update({
              'base_fare': _intOf(_fares[cat]!['base']!),
              'per_km': _intOf(_fares[cat]!['per_km']!),
              'per_minute': _intOf(_fares[cat]!['per_min']!),
              'minimum_fare': _intOf(_fares[cat]!['minimum_fare']!),
              'commission_percentage': _intOf(_fares[cat]!['commission']!),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('category', cat)
            .eq('is_active', true)
            .select();
        if ((rows as List).isEmpty) {
          failure.add(
            'tarifa de $cat (0 linhas — sessão sem permissão admin?)',
          );
        }
      }

      // Recompensa por convite (configurável — 1.3/3.1).
      final rewardRows = await _db.from('kupon_settings').upsert({
        'key': 'referral_reward_amount',
        'value': _intOf(_referralRewardCtrl),
      }, onConflict: 'key').select();
      if ((rewardRows as List).isEmpty) {
        failure.add('recompensa por convite (0 linhas)');
      }

      // 2.4 — aviso sonoro de fim de viagem (texto + raio de accionamento).
      final announceMsg = _rideEndAnnounceCtrl.text.trim();
      if (announceMsg.isEmpty) {
        failure.add('aviso de fim de viagem (mensagem vazia)');
      } else {
        final announceRows = await _db.from('kupon_settings').upsert({
          'key': 'ride_end_announcement',
          'value': announceMsg,
        }, onConflict: 'key').select();
        if ((announceRows as List).isEmpty) {
          failure.add('aviso de fim de viagem (0 linhas)');
        }
      }
      final announceRadiusRows = await _db.from('kupon_settings').upsert({
        'key': 'ride_end_announce_distance_m',
        'value': _intOf(_rideEndRadiusCtrl),
      }, onConflict: 'key').select();
      if ((announceRadiusRows as List).isEmpty) {
        failure.add('raio do aviso de fim de viagem (0 linhas)');
      }

      // [2.5] finos da cadeia — raio, idade da solicitação e janela.
      final chainSpecs = <(String, String, TextEditingController)>[
        ('chain_max_pickup_km', 'raio do embarque da cadeia', _chainRadiusCtrl),
        ('chain_max_trip_age_min', 'idade máx. da solicitação', _chainAgeCtrl),
        ('chain_reserve_seconds', 'janela do aceite em cadeia', _chainWindowCtrl),
      ];
      for (final (key, label, ctrl) in chainSpecs) {
        final rows = await _db.from('kupon_settings').upsert({
          'key': key,
          'value': _intOf(ctrl),
        }, onConflict: 'key').select();
        if ((rows as List).isEmpty) {
          failure.add('$label da cadeia (0 linhas)');
        }
      }

      // Cancelamentos [fase 4] — faixas + limites.
      final capInts = <(String, String, TextEditingController)>[
        ('cancel_delay_warn_min', 'aviso de atraso', _capWarnMinCtrl),
        ('cancel_delay_free_min', 'atraso livre', _capFreeMinCtrl),
        ('cancel_stall_min', 'sem progresso', _capStallMinCtrl),
        ('cancel_debt_review_threshold', 'limiar de revisão', _capRevThreshCtrl),
        ('cancel_dispute_paid_window_days', 'janela da contestação', _capDisputeDaysCtrl),
      ];
      for (final (key, label, ctrl) in capInts) {
        final rows = await _db.from('kupon_settings').upsert({
          'key': key,
          'value': _intOf(ctrl),
        }, onConflict: 'key').select();
        if ((rows as List).isEmpty) {
          failure.add('$label do cancelamento (0 linhas)');
        }
      }
      final bandRows = await _db.from('kupon_settings').upsert({
        'key': 'cancel_fee_bands',
        'value': [
          [_intOf(_capFee1Ctrl), 1],
          [_intOf(_capFee2Ctrl), 3],
          [_intOf(_capFee3Ctrl), 5],
          [_intOf(_capFee4Ctrl), null],
        ],
      }, onConflict: 'key').select();
      if ((bandRows as List).isEmpty) {
        failure.add('faixas de taxa do cancelamento (0 linhas)');
      }

      for (var i = 0; i < _windowFields.length; i += 5) {
        final id = _windowFields[i + 4].text.trim();
        if (id.isEmpty) continue;
        final rows = await _db
            .from('peak_windows')
            .update({
              'name': _windowFields[i].text.trim(),
              'start_hour': _intOf(_windowFields[i + 1]),
              'end_hour': _intOf(_windowFields[i + 2]),
              'multiplier':
                  double.tryParse(_windowFields[i + 3].text.trim()) ?? 1.0,
            })
            .eq('id', id)
            .select();
        if ((rows as List).isEmpty) {
          failure.add('janela "${_windowFields[i].text.trim()}" (0 linhas)');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          failure.isEmpty
              ? const SnackBar(
                  content: Text(
                    'Configurações salvas e aplicadas com sucesso!',
                  ),
                  backgroundColor: Color(0xFF4CAF88),
                )
              : SnackBar(
                  content: Text(
                    'Gravação FALHOU para: ${failure.join(' · ')}. '
                    'Verifica se tua conta tem role admin na tabela users.',
                  ),
                  backgroundColor: const Color(0xFFCF6679),
                  duration: const Duration(seconds: 6),
                ),
        );
        // Recarrega para actualizar as datas de alteração e o histórico.
        if (failure.isEmpty) await _loadSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar configurações: $e'),
            backgroundColor: const Color(0xFFCF6679),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Histórico de auditoria — últimas 40 alterações da base.
  /// Falha graciosa (tabela pode não existir numa base antiga).
  Future<void> _loadHistory() async {
    try {
      final rows = await _db
          .from('config_change_log')
          .select('table_name,row_key,changes,changed_at')
          .order('changed_at', ascending: false)
          .limit(40);
      if (!mounted) return;
      setState(() {
        _history = [for (final r in (rows as List)) Map.from(r as Map)];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _history = const <Map<String, dynamic>>[];
      });
    }
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        'às ${two(local.hour)}:${two(local.minute)}';
  }

  String _historyTableLabel(String table) {
    switch (table) {
      case 'tariffs':
        return 'Tarifa';
      case 'peak_windows':
        return 'Janela de demanda';
      case 'kupon_settings':
        return 'Configuração';
      case 'driver_packages':
        return 'Pacote de motorista';
      default:
        return table;
    }
  }

  /// Resumo legível das colunas alteradas: "base_fare 200 → 210".
  String _historyChangeSummary(Map<String, dynamic> changes) {
    final parts = <String>[];
    for (final key in changes.keys) {
      final pair = changes[key];
      if (pair is List && pair.length >= 2) {
        String fmt(dynamic v) {
          final s = '$v';
          return s.startsWith('"') ? s.replaceAll('"', '') : s;
        }

        parts.add('$key: ${fmt(pair[0])} → ${fmt(pair[1])}');
      }
    }
    return parts.join(' · ');
  }

  int _intOf(TextEditingController ctrl) => int.tryParse(ctrl.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: _loading
            ? const Center(child: KuponLoader())
            : RefreshIndicator(
                onRefresh: _loadSettings,
                color: AppTheme.primaryContainer,
                backgroundColor: AppTheme.surfaceContainerLow,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderBar(),
                      const SizedBox(height: 18),
                      _buildWarningBanner(),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Tarifas por Categoria de Veículo',
                        'Configure tarifas base, por km, por minuto, mínimo e comissão da plataforma para cada modalidade.',
                        Icons.directions_car_filled_rounded,
                      ),
                      const SizedBox(height: 14),
                      ..._categories.map(
                        (cat) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildFareCategoryCard(cat),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader(
                        'Janelas de Demanda',
                        'Multiplicadores aplicados em janelas de pico e no período noturno (tabela peak_windows).',
                        Icons.tune_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildPeakWindowsCard(),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        'Recompensa por Convite',
                        'Valor (Kz) por convite validado — usado nas boas-vindas do convidado e na recompensa pendente do convidante (configuração referral_reward_amount).',
                        Icons.card_giftcard_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildReferralRewardCard(),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        'Aviso de Fim de Viagem',
                        'Mensagem falada (voz do telemóvel) ao motorista quando falta ~600 m; 1× por viagem (configuração ride_end_announcement / ride_end_announce_distance_m).',
                        Icons.record_voice_over_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildRideEndAnnounceCard(),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        'Pedidos em Cadeia',
                        'Raio do embarque do próximo passageiro, idade máxima da solicitação e janela que o motorista tem para aceitar em cadeia (configurações chain_max_pickup_km / chain_max_trip_age_min / chain_reserve_seconds).',
                        Icons.link_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildChainCard(),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        'Regras de Cancelamento',
                        'Faixas de taxa por deslocação do motorista, atrasos, '
                        'deteção de sem progresso e contestação de dívidas '
                        '(configurações cancel_fee_bands / cancel_delay_* / '
                        'cancel_stall_min / cancel_debt_review_threshold / '
                        'cancel_dispute_paid_window_days).',
                        Icons.cancel_presentation_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildCancelCard(),
                      const SizedBox(height: 12),
                      _buildSaveButton(),
                      const SizedBox(height: 28),
                      _buildHistoryCard(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildReferralRewardCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppTheme.primaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'VALOR POR CONVITE (Kz)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _referralRewardCtrl,
              keyboardType: const TextInputType.numberWithOptions(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                suffixText: 'Kz',
                suffixStyle: TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideEndAnnounceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: AppTheme.primaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'MENSAGEM FALADA (TTS do dispositivo)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _rideEndRadiusCtrl,
                  keyboardType: const TextInputType.numberWithOptions(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixText: 'm',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rideEndAnnounceCtrl,
            maxLines: 3,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Caro KupaKamba, antes de sair…',
              hintStyle: TextStyle(color: AppTheme.onSurfaceVariant),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.surfaceContainerHighest),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [2.5] finos da cadeia — 3 números editáveis.
  Widget _buildChainCard() {
    Widget field(String label, String suffix, TextEditingController ctrl) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                suffixText: suffix,
                suffixStyle: TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          field('RAIO DO EMBARQUE', 'km', _chainRadiusCtrl),
          const SizedBox(width: 12),
          field('IDADE MÁX.', 'min', _chainAgeCtrl),
          const SizedBox(width: 12),
          field('JANELA DO ACEITE', 's', _chainWindowCtrl),
        ],
      ),
    );
  }

  /// Cancelamentos [fase 4] — faixas de taxa (4) + limites (5).
  Widget _buildCancelCard() {
    Widget field(String label, String suffix, TextEditingController ctrl) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                suffixText: suffix,
                suffixStyle: TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceContainerHighest),
      ),
      child: Column(
        children: [
          Row(
            children: [
              field('TAXA < 1 KM', 'Kz', _capFee1Ctrl),
              const SizedBox(width: 12),
              field('TAXA 1–3 KM', 'Kz', _capFee2Ctrl),
              const SizedBox(width: 12),
              field('TAXA 3–5 KM', 'Kz', _capFee3Ctrl),
              const SizedBox(width: 12),
              field('TAXA 5+ KM', 'Kz', _capFee4Ctrl),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              field('AVISO ATRASO', 'min', _capWarnMinCtrl),
              const SizedBox(width: 12),
              field('ATRASO LIVRE', 'min', _capFreeMinCtrl),
              const SizedBox(width: 12),
              field('SEM PROGRESSO', 'min', _capStallMinCtrl),
              const SizedBox(width: 12),
              field('REVISÃO (PEND)', 'u', _capRevThreshCtrl),
              const SizedBox(width: 12),
              field('CONTESTAR DIAS', 'd', _capDisputeDaysCtrl),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.settings_suggest_rounded,
            color: AppTheme.primaryContainer,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Configurações do Sistema',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE5E2E1),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MOTOR DE REGRAS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryContainer,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Ajuste dinâmico de tarifas, comissões e multiplicadores operacionais',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Recarregar',
          onPressed: _loadSettings,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFE5E2E1),
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5C842).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF5C842).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5C842).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFF5C842),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impacto Operacional Imediato',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF5C842),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Qualquer alteração salva nesta página é aplicada em tempo real para todas as novas cotações e corridas solicitadas no aplicativo.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11.5,
                    height: 1.4,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryContainer),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE5E2E1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildFareCategoryCard(String category) {
    final catLabels = {
      'moto': 'KupON Moto (Classe 2 Rodas)',
      'car_standard': 'KupON Standard (Econômico)',
      'car_comfort': 'KupON Comfort (Espaço e Ar)',
      'car_luxury': 'KupON Black (Executivo / Luxury)',
    };
    final catIcons = {
      'moto': Icons.two_wheeler_rounded,
      'car_standard': Icons.directions_car_rounded,
      'car_comfort': Icons.directions_car_filled_rounded,
      'car_luxury': Icons.local_taxi_rounded,
    };
    final color = category == 'car_luxury'
        ? const Color(0xFFF5C842)
        : category == 'moto'
        ? const Color(0xFF4CAF88)
        : AppTheme.primaryContainer;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(catIcons[category], color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catLabels[category] ?? category.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE5E2E1),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Última alteração: ${_fmtDate(_tariffUpdatedAt[category])}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9C9896),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              if (isNarrow) {
                return Column(
                  children: _fareFields.map((field) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildNumericField(
                        field.$2,
                        _fares[category]![field.$1]!,
                        field.$3,
                        color,
                      ),
                    );
                  }).toList(),
                );
              }
              return Row(
                children: _fareFields.map((field) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _buildNumericField(
                        field.$2,
                        _fares[category]![field.$1]!,
                        field.$3,
                        color,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeakWindowsCard() {
    if (_windowFields.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: Color(0xFFF5C842),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nenhuma janela de demanda ativa encontrada. Adicione janelas na tabela peak_windows.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final windows = <Map<String, dynamic>>[];
    for (var i = 0; i < _windowFields.length; i += 5) {
      windows.add({
        'name': _windowFields[i],
        'start': _windowFields[i + 1],
        'end': _windowFields[i + 2],
        'mult': _windowFields[i + 3],
      });
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < windows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFF2A2A2A)),
              ),
            _buildWindowRow(
              windows[i]['name'],
              windows[i]['start'],
              windows[i]['end'],
              windows[i]['mult'],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calculate_outlined,
                  size: 20,
                  color: Color(0xFF4CAF88),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'O multiplicador é aplicado à tarifa base quando a hora atual cai dentro da janela. Noite (22h–05h) e pico (06h–09h, 17h–20h).',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11.5,
                      color: const Color(0xFFE2BFB0).withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowRow(
    TextEditingController nameCtrl,
    TextEditingController startCtrl,
    TextEditingController endCtrl,
    TextEditingController multCtrl,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWindowName(nameCtrl),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildHourField('Início (h)', startCtrl)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildHourField('Fim (h)', endCtrl)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildHourField('Mult (x)', multCtrl, isMult: true),
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: _buildWindowName(nameCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _buildHourField('Início (h)', startCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _buildHourField('Fim (h)', endCtrl)),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHourField('Mult (x)', multCtrl, isMult: true),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWindowName(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFE5E2E1),
      ),
      decoration: InputDecoration(
        labelText: 'Nome da janela',
        labelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        fillColor: AppTheme.surfaceContainerLowest,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppTheme.primaryContainer,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildHourField(
    String label,
    TextEditingController ctrl, {
    bool isMult = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isMult
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      textAlign: TextAlign.center,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        color: isMult ? const Color(0xFFF5C842) : const Color(0xFFE5E2E1),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        fillColor: AppTheme.surfaceContainerLowest,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isMult ? const Color(0xFFF5C842) : AppTheme.primaryContainer,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildNumericField(
    String label,
    TextEditingController ctrl,
    IconData icon,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: accentColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE5E2E1),
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              fillColor: AppTheme.surfaceContainerLowest,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Histórico de auditoria — datas de alteração de tarifas e outras
  /// configurações (tabela config_change_log, alimentada por trigger).
  Widget _buildHistoryCard() {
    if (_history.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF575757).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: Color(0xFFE5E2E1),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Histórico de Alterações',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFE5E2E1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Últimas alterações gravadas na base (tarifas, janelas, pacotes e configurações).',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: const Color(0xFF9C9896),
            ),
          ),
          const SizedBox(height: 14),
          ..._history.take(20).map((entry) {
            final changes = entry['changes'] is Map
                ? Map<String, dynamic>.from(entry['changes'] as Map)
                : <String, dynamic>{};
            final summary = _historyChangeSummary(changes);
            // Nos 'tariffs' o row_key é o uuid -> mostra o nome da categoria.
            String rowLabel = '${entry['row_key'] ?? ''}';
            final catForId = _tariffIds.entries
                .where((e) => e.value == rowLabel)
                .map((e) => e.key)
                .firstOrNull;
            if (catForId != null) rowLabel = catForId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_historyTableLabel('${entry['table_name'] ?? ''}')}'
                          '${rowLabel.isEmpty ? '' : ' (${rowLabel.replaceAll('_', ' ')})'} · '
                          '${_fmtDate(DateTime.tryParse('${entry['changed_at'] ?? ''}'))}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFC9C5C2),
                          ),
                        ),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: const Color(0xFF9C9896),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryContainer,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
          shadowColor: AppTheme.primaryContainer.withValues(alpha: 0.4),
        ),
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Icon(Icons.save_rounded, size: 20, color: Colors.black),
        label: Text(
          _saving
              ? 'A Salvar Alterações...'
              : 'Salvar e Aplicar Tarifas Globais',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
