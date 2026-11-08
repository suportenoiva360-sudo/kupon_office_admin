import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/app_snackbar.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Revisão de verificações faciais [fase 3]: lista as selfies submetidas pelos
/// motoristas, mostra a imagem por URL assinada (o bucket é privado) e permite
/// aprovar, rejeitar ou bloquear através da RPC `review_face_check`.
///
/// As selfies marcadas `liveness_mode = degraded` avançaram sem um sinal do
/// ML Kit (olhos ou rotação) e são as que mais precisam de revisão humana; o
/// servidor já as considerou aprovadas, mas ficam identificadas nesta lista.
class AdminFaceReviewsPage extends StatefulWidget {
  const AdminFaceReviewsPage({super.key});

  @override
  State<AdminFaceReviewsPage> createState() => _AdminFaceReviewsPageState();
}

class _AdminFaceReviewsPageState extends State<AdminFaceReviewsPage> {
  final _db = Supabase.instance.client;

  bool _loading = true;
  bool _loadFailed = false;
  String? _busyId;
  String _filter = 'pending';
  int _limit = 300;
  List<Map<String, dynamic>> _rows = [];

  /// URLs assinadas por caminho — evita renovar a cada rebuild.
  final Map<String, Future<String?>> _urlFutures = {};

  static const _bucket = 'driver-verifications';

  static const _filters = [
    ('pending', 'Pendentes'),
    ('degraded', 'Degradadas'),
    ('approved', 'Aprovadas'),
    ('rejected', 'Rejeitadas'),
    ('blocked', 'Bloqueadas'),
    ('all', 'Todas'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _db
          .from('driver_face_checks')
          .select()
          .order('created_at', ascending: false)
          .limit(_limit);

      final rows = data
          .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
          .toList();

      // Join em dois passos: evita ambiguidade do PostgREST entre
      // `drivers.user_id` e `driver_face_checks.reviewed_by`.
      final ids = rows
          .map((r) => r['driver_id'])
          .whereType<String>()
          .toSet()
          .toList();
      final driversById = <String, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final drivers = await _db
            .from('drivers')
            .select('id, user_id, users(name, phone)')
            .inFilter('id', ids);
        for (final d in drivers) {
          final map = Map<String, dynamic>.from(d);
          driversById[map['id'] as String] = map;
        }
      }
      for (final row in rows) {
        row['_driver'] = driversById[row['driver_id']];
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  // ── Dados derivados ──────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 'pending':
        return _rows.where((r) => r['status'] == 'pending').toList();
      case 'degraded':
        return _rows.where((r) => r['liveness_mode'] == 'degraded').toList();
      case 'approved':
        return _rows.where((r) => r['status'] == 'approved').toList();
      case 'rejected':
        return _rows.where((r) => r['status'] == 'rejected').toList();
      case 'blocked':
        return _rows.where((r) => r['status'] == 'blocked').toList();
      default:
        return _rows;
    }
  }

  int _count(bool Function(Map<String, dynamic>) test) =>
      _rows.where(test).length;

  // ── Selfies ──────────────────────────────────────────────────────────────

  Future<String?> _signedUrl(String path) {
    return _urlFutures.putIfAbsent(path, () async {
      try {
        return await _db.storage.from(_bucket).createSignedUrl(path, 600);
      } catch (_) {
        return null;
      }
    });
  }

  // ── Revisão ──────────────────────────────────────────────────────────────

  Future<void> _review(Map<String, dynamic> row, String status) async {
    final labels = {
      'approved': ('Aprovar verificação', 'Aprovar'),
      'rejected': ('Rejeitar verificação', 'Rejeitar'),
      'blocked': ('Bloquear motorista', 'Bloquear'),
    };
    final (title, action) = labels[status]!;

    final note = await _askNote(
      title: title,
      action: action,
      requireNote: status != 'approved',
      description: switch (status) {
        'approved' =>
          'Marca a verificação como válida e liberta o motorista para ficar '
              'online hoje.',
        'rejected' =>
          'A selfie é recusada. O motorista pode tentar novamente enquanto '
              'tiver tentativas disponíveis.',
        _ =>
          'Bloqueia o motorista na verificação facial. O desbloqueio é feito '
              'no detalhe do motorista.',
      },
    );
    if (note == null) return;

    setState(() => _busyId = row['id'] as String);
    try {
      await _db.rpc(
        'review_face_check',
        params: {
          'p_check_id': row['id'],
          'p_status': status,
          'p_note': note.isEmpty ? null : note,
        },
      );
      if (!mounted) return;
      _toast('Verificação ${action.toLowerCase()} com sucesso.');
      setState(() => _busyId = null);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      _toast('Erro ao rever: $e', error: true);
    }
  }

  Future<String?> _askNote({
    required String title,
    required String action,
    required String description,
    required bool requireNote,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE5E2E1),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: const Color(0xFFE2BFB0),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: const Color(0xFFE5E2E1),
              ),
              decoration: InputDecoration(
                hintText: requireNote
                    ? 'Nota da decisão (obrigatória)'
                    : 'Nota da decisão (opcional)',
                hintStyle: const TextStyle(color: Color(0xFFE2BFB0)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: const Color(0xFF050505),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              action,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (result == null) return null;
    if (requireNote && result.isEmpty) {
      _toast('Nota obrigatória para esta decisão.', error: true);
      return null;
    }
    return result;
  }

  Future<void> _openSelfie(Map<String, dynamic> row) async {
    final path = row['selfie_path'] as String?;
    if (path == null || path.isEmpty) {
      _toast('Esta verificação não tem selfie associada.', error: true);
      return;
    }
    final url = await _signedUrl(path);
    if (!mounted) return;
    if (url == null) {
      _toast('Não foi possível gerar o link da selfie.', error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driverName(row),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE5E2E1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmtDate(row['created_at'])} · ${row['driver_id']}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Não foi possível carregar a selfie.'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10.5,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () =>
                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Abrir'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Formatação ───────────────────────────────────────────────────────────

  String _driverName(Map<String, dynamic> row) {
    final driver = row['_driver'] as Map<String, dynamic>? ?? const {};
    final user = driver['users'] as Map<String, dynamic>? ?? const {};
    return user['name'] as String? ?? 'Motorista';
  }

  String _driverPhone(Map<String, dynamic> row) {
    final driver = row['_driver'] as Map<String, dynamic>? ?? const {};
    final user = driver['users'] as Map<String, dynamic>? ?? const {};
    return user['phone'] as String? ?? '';
  }

  String _shortId(Object? value) {
    final v = value?.toString() ?? '';
    return v.length >= 8 ? v.substring(0, 8) : v;
  }

  String _fmtDate(Object? v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    if (d == null) return '';
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    showAdminSnackBar(
      context,
      message: msg,
      type: error ? AdminSnackType.error : AdminSnackType.success,
    );
  }

  // ── Interface ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(child: KuponLoader()),
      );
    }

    final rows = _filtered;
    final showMore = _rows.length >= _limit;
    final emptyText = _loadFailed ? 'Sem dados' : 'Nada neste filtro';

    final header = <Widget>[
      _buildHeader(),
      const SizedBox(height: 16),
      if (_loadFailed) ...[_buildError(), const SizedBox(height: 16)],
      _buildKpis(),
      const SizedBox(height: 24),
      _buildFilters(),
      const SizedBox(height: 12),
    ];

    // ListView.builder para as miniaturas só pedirem URL assinada quando
    // entram no ecrã.
    final tail = rows.isEmpty ? 1 : rows.length;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryContainer,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          itemCount: header.length + tail + (showMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < header.length) return header[index];
            final i = index - header.length;
            if (rows.isEmpty) {
              return Column(
                children: [
                  _buildEmpty(emptyText),
                  const SizedBox(height: 32),
                ],
              );
            }
            if (i < rows.length) return _buildCard(rows[i]);
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 32),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _limit += 300;
                    _load();
                  },
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: const Text('Carregar mais'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            Icons.face_retouching_natural_rounded,
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
                'Verificações faciais',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFE5E2E1),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Selfies dos motoristas para revisão manual · retenção de 30 dias',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Atualizar dados',
          onPressed: _load,
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

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorContainer.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFCF6679)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Não foi possível carregar as verificações. Verifica a ligação '
              'e tenta novamente.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12.5,
                color: const Color(0xFFE2BFB0),
              ),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Tentar')),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    Widget kpi(String label, String value, Color color) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: kpi(
            'Pendentes',
            _count((r) => r['status'] == 'pending').toString(),
            const Color(0xFFFFB74D),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: kpi(
            'Degradadas por rever',
            _count(
              (r) =>
                  r['liveness_mode'] == 'degraded' && r['status'] == 'pending',
            ).toString(),
            const Color(0xFF6EA8FE),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: kpi(
            'Aprovadas',
            _count((r) => r['status'] == 'approved').toString(),
            const Color(0xFF4CAF88),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: kpi(
            'Rejeitadas',
            _count((r) => r['status'] == 'rejected').toString(),
            const Color(0xFFCF6679),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in _filters)
          ChoiceChip(
            label: Text(label),
            selected: _filter == value,
            onSelected: (_) => setState(() => _filter = value),
            selectedColor: AppTheme.primaryContainer,
            labelStyle: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _filter == value
                  ? const Color(0xFF050505)
                  : const Color(0xFFE2BFB0),
            ),
            backgroundColor: AppTheme.surfaceContainerLow,
          ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? 'pending';
    final degraded = row['liveness_mode'] == 'degraded';
    final path = row['selfie_path'] as String?;
    final busy = _busyId == row['id'];
    final (statusLabel, statusColor) = switch (status) {
      'approved' => ('Aprovada', const Color(0xFF4CAF88)),
      'rejected' => ('Rejeitada', const Color(0xFFCF6679)),
      'blocked' => ('Bloqueada', const Color(0xFFCF6679)),
      _ => ('Pendente', const Color(0xFFFFB74D)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: degraded && status == 'pending'
              ? const Color(0xFF6EA8FE).withValues(alpha: 0.5)
              : AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumb(path),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _driverName(row),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE5E2E1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _chip(statusLabel, statusColor),
                        if (degraded) ...[
                          const SizedBox(width: 6),
                          _chip(
                            'Liveness degradado',
                            const Color(0xFF6EA8FE),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (_driverPhone(row).isNotEmpty) _driverPhone(row),
                        'ID ${_shortId(row['driver_id'])}',
                        'Dia ${row['checked_on'] ?? '—'}',
                        'Tentativa ${row['attempts_in_day'] ?? '—'}',
                      ].join(' · '),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmtDate(row['created_at'])}'
                      '${row['reviewed_at'] != null ? ' · revista em ${_fmtDate(row['reviewed_at'])}' : ''}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: const Color(0xFFE2BFB0).withValues(alpha: 0.55),
                      ),
                    ),
                    if (row['failure_reason'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Motivo: ${row['failure_reason']}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11.5,
                          color: const Color(0xFFCF6679),
                        ),
                      ),
                    ],
                    if (row['review_note'] != null &&
                        (row['review_note'] as String).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Nota: ${row['review_note']}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11.5,
                          color: const Color(0xFFE2BFB0),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: path == null || path.isEmpty
                    ? null
                    : () => _openSelfie(row),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Ver selfie'),
              ),
              const SizedBox(width: 8),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                TextButton.icon(
                  onPressed: () => _review(row, 'approved'),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Aprovar'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF88),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _review(row, 'rejected'),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Rejeitar'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFB74D),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _review(row, 'blocked'),
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('Bloquear'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFCF6679),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumb(String? path) {
    const size = 76.0;
    if (path == null || path.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.no_photography_outlined,
          color: Color(0xFFE2BFB0),
          size: 22,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FutureBuilder<String?>(
        future: _signedUrl(path),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Container(
              width: size,
              height: size,
              color: AppTheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final url = snapshot.data;
          if (url == null) {
            return Container(
              width: size,
              height: size,
              color: AppTheme.surfaceContainerHighest,
              child: const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFE2BFB0),
                size: 22,
              ),
            );
          }
          return Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: size,
              height: size,
              color: AppTheme.surfaceContainerHighest,
              child: const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFE2BFB0),
                size: 22,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmpty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
