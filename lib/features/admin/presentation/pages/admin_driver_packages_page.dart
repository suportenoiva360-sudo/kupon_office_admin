import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// KupON v2.1 — Gestão de pacotes do motorista + configuração global
/// (spec kupon_specs.md §4/§5 e §15.6: preços, viagens grátis, bónus, cotas).
class AdminDriverPackagesPage extends StatefulWidget {
  const AdminDriverPackagesPage({super.key});

  @override
  State<AdminDriverPackagesPage> createState() =>
      _AdminDriverPackagesPageState();
}

class _AdminDriverPackagesPageState extends State<AdminDriverPackagesPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _packages = [];
  final Map<String, Map<String, dynamic>> _settings = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.from('driver_packages').select('*').order('price'),
        _db.from('kupon_settings').select('key, value'),
      ]);
      if (!mounted) return;
      setState(() {
        _packages = List<Map<String, dynamic>>.from(results[0] as List);
        _settings.clear();
        for (final row in List<Map<String, dynamic>>.from(results[1] as List)) {
          _settings[row['key'] as String] = row;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Erro ao carregar: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor:
            error ? const Color(0xFFCF6679) : const Color(0xFF4CAF88),
      ),
    );
  }

  String _fmtKz(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  // ---------------------------------------------------------------
  // Pacotes CRUD Form (Dialog Responsivo)
  // ---------------------------------------------------------------
  Future<void> _openPackageForm([Map<String, dynamic>? pkg]) async {
    final nameCtrl = TextEditingController(text: pkg?['name'] ?? '');
    final priceCtrl = TextEditingController(
        text: pkg != null ? '${pkg['price']}' : '');
    final daysCtrl = TextEditingController(
        text: '${pkg?['duration_days'] ?? 30}');
    final quotaCtrl = TextEditingController(
        text: '${pkg?['trip_quota'] ?? 0}');
    var isActive = pkg?['is_active'] as bool? ?? true;

    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: AppTheme.primaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pkg == null ? 'Novo Pacote KupON' : 'Editar Pacote',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            Text(
                              pkg == null
                                  ? 'Crie um plano de acesso para os motoristas'
                                  : 'Atualize os parâmetros de ${pkg['name']}',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AppTheme.outlineVariant),
                  const SizedBox(height: 20),

                  // Campos
                  _field(
                    nameCtrl,
                    'Nome do Pacote (ex: START, PLUS, PRO, MAX)',
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          priceCtrl,
                          'Preço (Kup / Kz)',
                          numeric: true,
                          prefixIcon: Icons.payments_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          daysCtrl,
                          'Duração (dias)',
                          numeric: true,
                          prefixIcon: Icons.calendar_today_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _field(
                    quotaCtrl,
                    'Quota de viagens (0 = Ilimitadas)',
                    numeric: true,
                    prefixIcon: Icons.route_outlined,
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Pacote ativo (disponível para compra)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      value: isActive,
                      activeThumbColor: AppTheme.primaryContainer,
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppTheme.outlineVariant.withValues(alpha: 0.8),
                            ),
                            foregroundColor: AppTheme.onSurface,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryContainer,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (nameCtrl.text.trim().isEmpty ||
                                int.tryParse(priceCtrl.text) == null) {
                              _snack('Nome e preço válidos são obrigatórios.',
                                  error: true);
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                          child: Text(
                            pkg == null ? 'Criar Pacote' : 'Salvar Alterações',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final values = {
      'name': nameCtrl.text.trim(),
      'price': int.parse(priceCtrl.text),
      'duration_days': int.parse(daysCtrl.text),
      'trip_quota': int.parse(quotaCtrl.text),
      'is_active': isActive,
    };
    try {
      if (pkg == null) {
        await _db.from('driver_packages').insert(values);
      } else {
        await _db.from('driver_packages').update(values).eq('id', pkg['id']);
      }
      _snack(pkg == null ? 'Pacote criado com sucesso.' : 'Pacote atualizado.');
      await _load();
    } catch (e) {
      _snack('Erro ao guardar pacote: $e', error: true);
    }
  }

  Future<void> _togglePackage(Map<String, dynamic> pkg) async {
    try {
      await _db
          .from('driver_packages')
          .update({'is_active': pkg['is_active'] != true}).eq('id', pkg['id']);
      _snack(pkg['is_active'] == true
          ? 'Pacote pausado.'
          : 'Pacote ativado para venda.');
      await _load();
    } catch (e) {
      _snack('Erro ao alterar estado: $e', error: true);
    }
  }

  Future<void> _deletePackage(Map<String, dynamic> pkg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFCF6679), size: 24),
            SizedBox(width: 10),
            Text('Eliminar Pacote?'),
          ],
        ),
        content: Text(
          'Tem certeza que deseja eliminar "${pkg['name']}"?\n\n'
          'Motoristas com o pacote ativo mantêm o acesso até expirar. '
          'Se houver histórico vinculado no banco, o pacote não será removido para manter integridade.',
          style: const TextStyle(fontSize: 13.5, color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCF6679),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _db.from('driver_packages').delete().eq('id', pkg['id']);
      _snack('Pacote eliminado com sucesso.');
      await _load();
    } catch (e) {
      _snack(
          'Não foi possível eliminar (pacote em uso por motoristas): $e',
          error: true);
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool numeric = false,
    IconData? prefixIcon,
  }) {
    return TextField(
      controller: c,
      keyboardType: numeric ? TextInputType.number : null,
      style: const TextStyle(color: AppTheme.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12.5, color: AppTheme.onSurfaceVariant),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: AppTheme.primaryContainer)
            : null,
        filled: true,
        fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryContainer, width: 1.5),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // kupon_settings editor
  // ---------------------------------------------------------------
  Future<void> _saveSetting(String key, String value) async {
    try {
      await _db.from('kupon_settings').upsert({
        'key': key,
        'value': int.tryParse(value) != null
            ? int.parse(value)
            : jsonDecode(value),
      });
      _snack('Configuração "$key" guardada com sucesso.');
      await _load();
    } catch (e) {
      _snack('Erro ao guardar "$key": $e', error: true);
    }
  }

  // ---------------------------------------------------------------
  // UI Principal
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final activeCount = _packages.where((p) => p['is_active'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.primaryContainer,
          backgroundColor: AppTheme.surfaceContainerLow,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 24),

                      // KPI Cards
                      _buildKpiRow(activeCount),
                      const SizedBox(height: 32),

                      // Seção 1: Pacotes de Acesso do Motorista
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _sectionTitle('Pacotes de Acesso do Motorista',
                              Icons.workspace_premium_rounded),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => _openPackageForm(),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Novo Pacote'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryContainer,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gerencie os planos de assinatura disponíveis para os motoristas parceiros (taxa zero de comissão por período).',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: KuponLoader()),
                        )
                      else if (_packages.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Nenhum pacote cadastrado até ao momento.',
                              style: TextStyle(color: AppTheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 700;
                            if (isWide) {
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: _packages.map((pkg) {
                                  return SizedBox(
                                    width: (constraints.maxWidth - 16) / 2,
                                    child: _packageCard(pkg),
                                  );
                                }).toList(),
                              );
                            }
                            return Column(
                              children: _packages.map(_packageCard).toList(),
                            );
                          },
                        ),

                      const SizedBox(height: 36),
                      const Divider(height: 1, color: AppTheme.outlineVariant),
                      const SizedBox(height: 36),

                      // Seção 2: Configurações Globais (kupon_settings)
                      _sectionTitle('Parâmetros Globais da Plataforma',
                          Icons.tune_rounded),
                      const SizedBox(height: 6),
                      const Text(
                        'Ajuste os incentivos de aprovação, escalões de bónus diários e as cotas de fidelidade sincronizadas em tempo real.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (_loading)
                        const SizedBox.shrink()
                      else
                        ..._buildGroupedSettings(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.primaryContainer.withValues(alpha: 0.35),
            ),
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: AppTheme.primaryContainer,
            size: 26,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pacotes & Parâmetros KupON',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Controlo de planos para motoristas, bonificações e cotas de mobilidade',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Recarregar dados',
          onPressed: _load,
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppTheme.onSurfaceVariant,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiRow(int activeCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpiCard(
              title: 'TOTAL DE PACOTES',
              value: '${_packages.length}',
              icon: Icons.inventory_2_outlined,
              color: AppTheme.primaryContainer,
            ),
            _kpiCard(
              title: 'PACOTES EM VENDA',
              value: '$activeCount ativos',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF4CAF88),
            ),
            _kpiCard(
              title: 'PARÂMETROS GLOBAIS',
              value: '${_settings.length} chaves',
              icon: Icons.settings_suggest_outlined,
              color: const Color(0xFFFFB74D),
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryContainer),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _packageCard(Map<String, dynamic> pkg) {
    final active = pkg['is_active'] == true;
    final price = pkg['price'] as int? ?? 0;
    final days = pkg['duration_days'] as int? ?? 0;
    final quota = pkg['trip_quota'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? AppTheme.primaryContainer.withValues(alpha: 0.5)
              : AppTheme.outlineVariant.withValues(alpha: 0.4),
          width: active ? 1.4 : 1,
        ),
        boxShadow: [
          if (active)
            BoxShadow(
              color: AppTheme.primaryContainer.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${pkg['name']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (active ? const Color(0xFF4CAF88) : const Color(0xFFCF6679))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (active ? const Color(0xFF4CAF88) : const Color(0xFFCF6679))
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                      size: 13,
                      color: active ? const Color(0xFF4CAF88) : const Color(0xFFCF6679),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      active ? 'À VENDA' : 'PAUSADO',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: active
                            ? const Color(0xFF4CAF88)
                            : const Color(0xFFCF6679),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Text(
                '${_fmtKz(price)} Kz',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryContainer,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ $days dias',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.route_outlined,
                  size: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  quota == 0 ? 'Viagens ilimitadas' : 'Até $quota corridas',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.percent_rounded,
                  size: 14,
                  color: Color(0xFF4CAF88),
                ),
                const SizedBox(width: 4),
                const Text(
                  '0% Comissão',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4CAF88),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          const SizedBox(height: 10),

          // Botões de Ação
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _openPackageForm(pkg),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: () => _togglePackage(pkg),
                icon: Icon(
                  active ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  size: 16,
                ),
                label: Text(active ? 'Pausar' : 'Ativar'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      active ? const Color(0xFFFFB74D) : const Color(0xFF4CAF88),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Eliminar Pacote',
                onPressed: () => _deletePackage(pkg),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFCF6679),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedSettings() {
    return [
      _settingsGroupCard(
        title: 'Boas-vindas ao Motorista',
        icon: Icons.card_giftcard_rounded,
        items: [
          _settingItem(
            'free_trips_count',
            'Viagens grátis por aprovação',
            'Número de corridas sem comissão atribuídas após ser aprovado.',
            suffix: 'viagens',
          ),
        ],
      ),
      const SizedBox(height: 16),
      _settingsGroupCard(
        title: 'Metas e Bónus de Produção',
        icon: Icons.military_tech_rounded,
        items: [
          _settingItem(
            'bonus_travel_count_min',
            'Viagens mínimas para bónus',
            'Gatilho diário mínimo de corridas para elegibilidade ao bónus.',
            suffix: 'viagens',
          ),
          _settingItem(
            'bonus_daily_budget',
            'Orçamento diário de bónus',
            'Teto máximo diário de gratificações distribuídas a motoristas.',
            suffix: 'Kup',
          ),
          _settingItem(
            'bonus_tiers',
            'Escalões de bónus (JSON)',
            'Estrutura de faixas para bonificação dinâmica (ex: 5/10/15 corridas).',
            isJson: true,
          ),
        ],
      ),
      const SizedBox(height: 16),
      _settingsGroupCard(
        title: 'Cotas de Fidelidade — Acumulação e Pagamento',
        icon: Icons.loyalty_rounded,
        items: [
          _settingItem(
            'cota_per_trip',
            'Cotas por viagem concluída',
            'Pontuação acumulada por cada viagem finalizada. Grátis/desconto 100%/passe não geram.',
            suffix: 'cotas',
          ),
          _settingItem(
            'cota_cost_bands',
            'Faixas de custo em cotas (JSON)',
            'Cotação de corridas pagas em cotas: até 3 km→50; 3–5 km→70; >5 km→70+10/km; cap perto do aeroporto→80+5/km (cap 90). Ex: [{"max_km":3,"cost":50},{"max_km":5,"cost":70},{"max_km":7,"cost":90},…]. Aplica-se a passageiro e 3.º.',
            isJson: true,
          ),
          _settingItem(
            'cota_cost_cap',
            'Faixa de cap (aeroporto) a partir de (km)',
            'Distância a partir da qual vale a faixa do cap (80+5/km, cap 90). 0 desativa o cap.',
            suffix: 'km',
          ),
          _settingItem(
            'cota_to_kup_rate',
            'Taxa de conversão cota→Kup (fallback)',
            'Valor do Kup por cota no fallback da conclusão: 1 cota = 40 Kup.',
            suffix: 'Kup/cota',
          ),
          _settingItem(
            'cota_validity_months',
            'Validade das cotas acumuladas',
            'Período em meses antes da expiração das cotas.',
            suffix: 'meses',
          ),
          _settingItem(
            'cota_monthly_cap',
            'Teto mensal de cotas',
            'Limite de cotas que um usuário pode acumular por mês.',
            suffix: 'cotas',
          ),
        ],
      ),
    ];
  }

  Widget _settingsGroupCard({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryContainer, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          const SizedBox(height: 10),
          ...items,
        ],
      ),
    );
  }

  Widget _settingItem(
    String key,
    String label,
    String description, {
    String? suffix,
    bool isJson = false,
  }) {
    final ctrl =
        TextEditingController(text: '${_settings[key]?['value'] ?? ''}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment:
            isJson ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  key,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.outline.withValues(alpha: 0.8),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: TextField(
              controller: ctrl,
              maxLines: isJson ? 3 : 1,
              style: TextStyle(
                fontSize: isJson ? 11.5 : 13.5,
                color: AppTheme.onSurface,
                fontFamily: isJson ? 'monospace' : null,
              ),
              decoration: InputDecoration(
                isDense: true,
                suffixText: suffix,
                suffixStyle: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.onSurfaceVariant,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryContainer,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Salvar $label',
            onPressed: () => _saveSetting(key, ctrl.text.trim()),
            icon: const Icon(
              Icons.save_rounded,
              size: 20,
              color: AppTheme.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
