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
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final tariffRows = await _db
          .from('tariffs')
          .select(
            'category,base_fare,per_km,per_minute,minimum_fare,commission_percentage,is_active',
          )
          .order('category');

      for (final row in (tariffRows as List)) {
        final cat = row['category'] as String?;
        if (cat == null || !_fares.containsKey(cat)) continue;
        if (row['is_active'] != true) continue;
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
    } catch (_) {
      // Keep defaults
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      for (final cat in _categories) {
        await _db.from('tariffs').update({
          'base_fare': _intOf(_fares[cat]!['base']!),
          'per_km': _intOf(_fares[cat]!['per_km']!),
          'per_minute': _intOf(_fares[cat]!['per_min']!),
          'minimum_fare': _intOf(_fares[cat]!['minimum_fare']!),
          'commission_percentage': _intOf(_fares[cat]!['commission']!),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('category', cat).eq('is_active', true);
      }

      for (var i = 0; i < _windowFields.length; i += 5) {
        final id = _windowFields[i + 4].text.trim();
        if (id.isEmpty) continue;
        await _db.from('peak_windows').update({
          'name': _windowFields[i].text.trim(),
          'start_hour': _intOf(_windowFields[i + 1]),
          'end_hour': _intOf(_windowFields[i + 2]),
          'multiplier':
              double.tryParse(_windowFields[i + 3].text.trim()) ?? 1.0,
        }).eq('id', id);
      }

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
                  Expanded(child: _buildHourField('Mult (x)', multCtrl, isMult: true)),
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
        color: isMult
            ? const Color(0xFFF5C842)
            : const Color(0xFFE5E2E1),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
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
          borderSide: BorderSide(
            color: isMult
                ? const Color(0xFFF5C842)
                : AppTheme.primaryContainer,
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