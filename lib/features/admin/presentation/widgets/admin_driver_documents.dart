import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Um ficheiro de documento do motorista guardado no Storage.
class DriverDocFile {
  final String name;
  final String path;
  final String url;

  const DriverDocFile({
    required this.name,
    required this.path,
    required this.url,
  });

  bool get isImage {
    final ext = name.split('.').last.toLowerCase();
    return <String>{
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'heic',
    }.contains(ext);
  }

  bool get isPdf => name.split('.').last.toLowerCase() == 'pdf';

  /// Etiqueta amigável a partir do nome do ficheiro.
  String get label {
    final lower = name.toLowerCase();
    if (lower.contains('bi') &&
        (lower.contains('frente') || lower.contains('front'))) {
      return 'BI Frente';
    }
    if (lower.contains('bi') &&
        (lower.contains('verso') ||
            lower.contains('traseiro') ||
            lower.contains('tras') ||
            lower.contains('back'))) {
      return 'BI Traseiro';
    }
    if (lower.contains('driving_license') || lower.contains('carta')) {
      return 'Carta de Condução';
    }
    if (lower.contains('crlv') || lower.contains('livrete')) {
      return 'Livrete (CRLV)';
    }
    if (lower.contains('insurance') || lower.contains('seguro')) {
      return 'Seguro';
    }
    if (lower.contains('vehicle') ||
        lower.contains('viatura') ||
        lower.contains('carro')) {
      return 'Foto da Viatura';
    }
    if (lower.contains('bi') ||
        lower.contains('passport') ||
        lower.contains('passaporte')) {
      return 'BI / Passaporte';
    }
    if (lower.contains('selfie') || lower.contains('photo')) return 'Foto';
    return name;
  }
}

/// Lista os documentos do motorista no bucket `driver-documents`.
/// Estrutura: uma pasta por motorista (`{driver_id}/` ou `{user_id}/`)
/// com os ficheiros dentro (ex.: `crlv.png`, `driving_license.png`).
/// Devolve [] quando não há ficheiros ou sem permissão — nunca mock.
Future<List<DriverDocFile>> fetchDriverDocuments({
  required String driverId,
  String? userId,
}) async {
  final bucket =
      Supabase.instance.client.storage.from('driver-documents');
  final prefixes = <String>[driverId];
  if (userId != null && userId.isNotEmpty && userId != driverId) {
    prefixes.add(userId);
  }
  final seen = <String>{};
  final out = <DriverDocFile>[];
  for (final prefix in prefixes) {
    try {
      await _collect(bucket, prefix, 0, seen, out);
    } catch (_) {
      // Sem acesso ou pasta inexistente: ignora este prefixo.
    }
  }
  return out;
}

Future<void> _collect(
  StorageFileApi bucket,
  String dir,
  int depth,
  Set<String> seen,
  List<DriverDocFile> out,
) async {
  final entries = await bucket.list(path: dir);
  for (final e in entries) {
    final name = e.name;
    if (name.isEmpty || name == '.emptyFolderPlaceholder') continue;
    final fullPath = '$dir/$name';
    if (e.id == null) {
      // Subpasta: desce um nível.
      if (depth < 2) await _collect(bucket, fullPath, depth + 1, seen, out);
      continue;
    }
    if (!seen.add(fullPath)) continue;
    try {
      final url = await bucket.createSignedUrl(fullPath, 3600);
      out.add(DriverDocFile(name: name, path: fullPath, url: url));
    } catch (_) {
      // Ficheiro sem acesso: não entra na lista.
    }
  }
}

/// Verifica os documentos obrigatórios para aprovação (BI frente + verso).
Future<({bool hasBiFront, bool hasBiBack})> checkMandatoryDocs({
  required String driverId,
  String? userId,
}) async {
  final docs = await fetchDriverDocuments(
    driverId: driverId,
    userId: userId,
  );
  var front = false;
  var back = false;
  for (final d in docs) {
    final lower = d.name.toLowerCase();
    if (!lower.contains('bi')) continue;
    if (lower.contains('frente') || lower.contains('front')) front = true;
    if (lower.contains('verso') ||
        lower.contains('traseiro') ||
        lower.contains('tras') ||
        lower.contains('back')) {
      back = true;
    }
  }
  return (hasBiFront: front, hasBiBack: back);
}

/// Grelha de documentos com miniaturas; toque abre o visualizador.
class DriverDocumentsSection extends StatefulWidget {
  final String driverId;
  final String? userId;

  const DriverDocumentsSection({
    super.key,
    required this.driverId,
    this.userId,
  });

  @override
  State<DriverDocumentsSection> createState() =>
      _DriverDocumentsSectionState();
}

class _DriverDocumentsSectionState extends State<DriverDocumentsSection> {
  bool _loading = true;
  List<DriverDocFile> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docs = await fetchDriverDocuments(
      driverId: widget.driverId,
      userId: widget.userId,
    );
    if (mounted) {
      setState(() {
        _docs = docs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: KuponLoader(size: 56)),
      );
    }
    if (_docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 18,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nenhum documento enviado',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _docs.length,
      itemBuilder: (context, i) => _DocThumb(
        doc: _docs[i],
        onTap: () => showDriverDocViewer(context, _docs[i]),
      ),
    );
  }
}

class _DocThumb extends StatelessWidget {
  final DriverDocFile doc;
  final VoidCallback onTap;

  const _DocThumb({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: doc.isImage
                  ? Image.network(
                      doc.url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                      errorBuilder: (_, _, _) => _thumbFallback(),
                    )
                  : _thumbFallback(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Text(
                doc.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Center(
      child: Icon(
        doc.isPdf
            ? Icons.picture_as_pdf_outlined
            : Icons.insert_drive_file_outlined,
        size: 30,
        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Visualizador de um documento em ecrã cheio.
Future<void> showDriverDocViewer(BuildContext context, DriverDocFile doc) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppTheme.surfaceContainerLow,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppTheme.onSurfaceVariant,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: doc.isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4,
                          child: Image.network(
                            doc.url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                    ? child
                                    : const Center(
                                        child: KuponLoader(size: 72),
                                      ),
                            errorBuilder: (_, _, _) => _viewerError(ctx, doc),
                          ),
                        ),
                      )
                    : _viewerError(ctx, doc),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => _openExternal(doc.url),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(
                  'Abrir no navegador',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _viewerError(BuildContext context, DriverDocFile doc) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          doc.isPdf
              ? Icons.picture_as_pdf_outlined
              : Icons.insert_drive_file_outlined,
          size: 56,
          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          'Pré-visualização indisponível',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

Future<void> _openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Diálogo de revisão antes de aprovar: mostra os documentos do
/// motorista e só depois permite aprovar.
Future<void> showDriverApprovalReview(
  BuildContext context, {
  required String driverId,
  required String? userId,
  required String driverName,
  required Future<void> Function() onApprove,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => _ApprovalReviewDialog(
      driverId: driverId,
      userId: userId,
      driverName: driverName,
      onApprove: onApprove,
    ),
  );
}

class _ApprovalReviewDialog extends StatefulWidget {
  final String driverId;
  final String? userId;
  final String driverName;
  final Future<void> Function() onApprove;

  const _ApprovalReviewDialog({
    required this.driverId,
    required this.userId,
    required this.driverName,
    required this.onApprove,
  });

  @override
  State<_ApprovalReviewDialog> createState() => _ApprovalReviewDialogState();
}

class _ApprovalReviewDialogState extends State<_ApprovalReviewDialog> {
  bool _saving = false;
  bool _checkingDocs = true;
  bool _hasBiFront = false;
  bool _hasBiBack = false;

  @override
  void initState() {
    super.initState();
    _checkDocs();
  }

  Future<void> _checkDocs() async {
    final res = await checkMandatoryDocs(
      driverId: widget.driverId,
      userId: widget.userId,
    );
    if (mounted) {
      setState(() {
        _hasBiFront = res.hasBiFront;
        _hasBiBack = res.hasBiBack;
        _checkingDocs = false;
      });
    }
  }

  bool get _docsOk => _hasBiFront && _hasBiBack;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceContainerLow,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.pending_actions_rounded,
                    color: const Color(0xFFF5C842),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rever antes de aprovar',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          widget.driverName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppTheme.onSurfaceVariant,
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_checkingDocs && !_docsOk)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5C842).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(
                              0xFFF5C842,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFF5C842),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Documentos obrigatórios em falta: '
                                '${[
                                  if (!_hasBiFront) 'BI Frente',
                                  if (!_hasBiBack) 'BI Traseiro',
                                ].join(', ')}. '
                                'A aprovação está bloqueada.',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFF5C842),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    DriverDocumentsSection(
                      driverId: widget.driverId,
                      userId: widget.userId,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_saving || _checkingDocs || !_docsOk) ? null : _approve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _saving ? 'A aprovar…' : 'Aprovar Motorista',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve() async {
    setState(() => _saving = true);
    try {
      await widget.onApprove();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }
}
