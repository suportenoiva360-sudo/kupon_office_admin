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

  final _fares = <String, Map<String, TextEditingController>>{};

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
  ];

  final _commissionCtrl = TextEditingController(text: '20');
  final _peakMultCtrl = TextEditingController(text: '1.5');
  final _nightMultCtrl = TextEditingController(text: '1.3');

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

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final rows = await _db.from('system_settings').select('*');
      final settings = <String, dynamic>{};
      for (final row in (rows as List)) {
        settings[row['key'] as String] = row['value'];
      }

      for (final cat in _categories) {
        for (final (field, _, _) in _fareFields) {
          final key = 'fare_${cat}_$field';
          if (settings.containsKey(key)) {
            _fares[cat]![field]!.text = '${settings[key]}';
          }
        }
      }
      if (settings.containsKey('driver_commission')) {
        _commissionCtrl.text = '${settings['driver_commission']}';
      }
      if (settings.containsKey('peak_multiplier')) {
        _peakMultCtrl.text = '${settings['peak_multiplier']}';
      }
      if (settings.containsKey('night_multiplier')) {
        _nightMultCtrl.text = '${settings['night_multiplier']}';
      }
    } catch (_) {
      // Keep defaults
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final upserts = <Map<String, dynamic>>[];

      for (final cat in _categories) {
        for (final (field, _, _) in _fareFields) {
          upserts.add({
            'key': 'fare_${cat}_$field',
            'value': _fares[cat]![field]!.text.trim(),
          });
        }
      }
      upserts.addAll([
        {'key': 'driver_commission', 'value': _commissionCtrl.text.trim()},
        {'key': 'peak_multiplier', 'value': _peakMultCtrl.text.trim()},
        {'key': 'night_multiplier', 'value': _nightMultCtrl.text.trim()},
      ]);

      await _db.from('system_settings').upsert(upserts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas e aplicadas com sucesso!'),
            backgroundColor: Color(0xFF4CAF88),
          ),
        );
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

  @override
  void dispose() {
    for (final map in _fares.values) {
      for (final ctrl in map.values) {
        ctrl.dispose();
      }
    }
    _commissionCtrl.dispose();
    _peakMultCtrl.dispose();
    _nightMultCtrl.dispose();
    super.dispose();
  }

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
                        'Configure os parâmetros de tarifação base, quilometragem e tempo para cada modalidade.',
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
                        'Variáveis Globais & Comissões',
                        'Controle de retenção de plataforma e multiplicadores dinâmicos de alta demanda.',
                        Icons.tune_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildGlobalParametersCard(),
                      const SizedBox(height: 32),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                'Ajuste dinâmico de tarifas, taxas de motoristas e multiplicadores operacionais',
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
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
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
                child: Text(
                  catLabels[category] ?? category.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE5E2E1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
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

  Widget _buildGlobalParametersCard() {
    final commissionVal = double.tryParse(_commissionCtrl.text) ?? 20;
    final driverKeeps = 100 - commissionVal;

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
          _buildSettingsRow(
            Icons.percent_rounded,
            'Taxa de Comissão KupOn (%)',
            'Percentual retido pela plataforma por corrida',
            _commissionCtrl,
            suffix: '%',
            color: AppTheme.primaryContainer,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFF2A2A2A)),
          ),
          _buildSettingsRow(
            Icons.trending_up_rounded,
            'Multiplicador de Hora de Ponta (x)',
            'Taxa aplicada em horários de pico ou alta procura',
            _peakMultCtrl,
            suffix: 'x',
            color: const Color(0xFFF5C842),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFF2A2A2A)),
          ),
          _buildSettingsRow(
            Icons.nightlight_round_outlined,
            'Multiplicador Turno Noturno (x)',
            'Taxa dinâmica para viagens entre 22h e 06h',
            _nightMultCtrl,
            suffix: 'x',
            color: const Color(0xFF5AB0FF),
          ),
          const SizedBox(height: 18),
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
                    'Exemplo de split: Em uma corrida de 5.000 Kz, o motorista recebe ${(5000 * (driverKeeps / 100)).toInt()} Kz (${driverKeeps.toInt()}%) e a KupOn retém ${(5000 * (commissionVal / 100)).toInt()} Kz (${commissionVal.toInt()}%).',
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

  Widget _buildSettingsRow(
    IconData icon,
    String label,
    String desc,
    TextEditingController ctrl, {
    required String suffix,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE5E2E1),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          height: 42,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            decoration: InputDecoration(
              suffixText: suffix,
              suffixStyle: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                borderSide: BorderSide(color: color, width: 1.5),
              ),
            ),
          ),
        ),
      ],
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          _saving ? 'A Salvar Alterações...' : 'Salvar e Aplicar Tarifas Globais',
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
