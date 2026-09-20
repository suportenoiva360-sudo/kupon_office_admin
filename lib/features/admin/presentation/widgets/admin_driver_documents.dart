import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bucket onde o app do motorista guarda os documentos (privado).
const _bucket = 'driver-documents';

/// Etiquetas para as chaves usadas no registo do motorista
/// (`{user_id}/{chave}.{ext}` e `drivers.documents_url`).
const _docLabels = <String, String>{
  'bi_frente': 'BI Frente',
  'bi_verso': 'BI Traseiro',
  'driving_license': 'Carta de Condução',
  'crlv': 'Livrete (CRLV)',
  'vehicle_insurance': 'Seguro do Veículo',
  'vehicle_inspection': 'Inspeção da Viatura',
  // chave antiga, ainda presente em ficheiros enviados antes do alinhamento
  'vehicle_photo': 'Foto da Viatura',
  'background_check': 'Verificação de Antecedentes',
  'selfie': 'Foto',
  'profile_photo': 'Foto de Perfil',
};

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
    final base = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    final key = base.toLowerCase();
    final known = _docLabels[key];
    if (known != null) return known;

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
      return 'Seguro do Veículo';
    }
    if (lower.contains('inspection') ||
        lower.contains('inspecao') ||
        lower.contains('inspeção') ||
        lower.contains('vistoria')) {
      return 'Inspeção da Viatura';
    }
    if (lower.contains('background')) {
      return 'Verificação de Antecedentes';
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

/// Resultado da leitura dos documentos: lista + erro legível (quando falhou).
class DriverDocsResult {
  final List<DriverDocFile> docs;
  final String? error;

  const DriverDocsResult(this.docs, {this.error});

  bool get hasError => error != null;
}

/// Lê os documentos do motorista. Duas fontes complementares:
///  1. Bucket `driver-documents` — pasta `{driver_id}/` ou `{user_id}/`
///     (ex.: `crlv.png`, `bi_frente.jpg`).
///  2. `drivers.documents_url` — mapa `{tipo: url pública}` gravado pelo app do
///     motorista no registo, usado quando não é possível listar a pasta.
/// Nunca devolve dados simulados; falhas são devolvidas em [DriverDocsResult.error].
Future<DriverDocsResult> loadDriverDocuments({
  required String driverId,
  String? userId,
  Map<String, dynamic>? docUrls,
}) async {
  final bucket = Supabase.instance.client.storage.from(_bucket);
  final prefixes = <String>[driverId];
  if (userId != null && userId.isNotEmpty && userId != driverId) {
    prefixes.add(userId);
  }

  final seen = <String>{};
  final out = <DriverDocFile>[];
  final errors = <String>[];

  for (final prefix in prefixes) {
    try {
      await _collect(bucket, prefix, 0, seen, out);
    } catch (e) {
      errors.add(_friendlyError(e));
    }
  }

  final fromDb = await _collectDocUrls(bucket, docUrls, seen);
  out.addAll(fromDb.docs);
  errors.addAll(fromDb.errors);

  out.sort((a, b) {
    final byRank = _docRank(a.name).compareTo(_docRank(b.name));
    return byRank != 0 ? byRank : a.name.compareTo(b.name);
  });

  if (out.isEmpty && errors.isNotEmpty) {
    return DriverDocsResult(const <DriverDocFile>[], error: errors.first);
  }
  return DriverDocsResult(out);
}

/// Compatibilidade: lista simples (usada pela verificação de obrigatórios).
Future<List<DriverDocFile>> fetchDriverDocuments({
  required String driverId,
  String? userId,
  Map<String, dynamic>? docUrls,
}) async {
  final res = await loadDriverDocuments(
    driverId: driverId,
    userId: userId,
    docUrls: docUrls,
  );
  return res.docs;
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
    if (_isFolder(e)) {
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

/// A API devolve pastas sem `id` nem `metadata`; ficheiros trazem sempre
/// metadata (tamanho/mimetype) e uma extensão. Testar os dois campos evita
/// tratar um ficheiro como pasta quando o `id` não vem na resposta.
bool _isFolder(FileObject e) {
  if (e.id != null || e.metadata != null) return false;
  return !e.name.contains('.');
}

Future<({List<DriverDocFile> docs, List<String> errors})> _collectDocUrls(
  StorageFileApi bucket,
  Map<String, dynamic>? docUrls,
  Set<String> seen,
) async {
  final docs = <DriverDocFile>[];
  final errors = <String>[];
  if (docUrls == null || docUrls.isEmpty) {
    return (docs: docs, errors: errors);
  }

  for (final entry in docUrls.entries) {
    final raw = entry.value?.toString() ?? '';
    if (raw.isEmpty) continue;
    final path = _objectPathFromUrl(raw);
    if (path == null || path.isEmpty || !seen.add(path)) continue;
    final name = path.split('/').last;
    try {
      final url = await bucket.createSignedUrl(path, 3600);
      docs.add(DriverDocFile(name: name, path: path, url: url));
    } catch (e) {
      errors.add(_friendlyError(e));
    }
  }
  return (docs: docs, errors: errors);
}

/// `.../object/(public|sign)/driver-documents/{uid}/{ficheiro}` -> `{uid}/{ficheiro}`
String? _objectPathFromUrl(String url) {
  final segments = Uri.tryParse(url)?.pathSegments;
  if (segments == null) return null;
  final index = segments.indexOf(_bucket);
  if (index < 0 || index + 1 >= segments.length) return null;
  return segments.sublist(index + 1).join('/');
}

String _friendlyError(Object e) {
  if (e is StorageException && e.statusCode == '403') {
    return 'Sem permissão para ler os documentos deste motorista.';
  }
  if (e is StorageException && e.statusCode == '400') {
    return 'Não foi possível ler os documentos deste motorista.';
  }
  return 'Não foi possível ler os documentos: $e';
}

int _docRank(String name) {
  final l = name.toLowerCase();
  if (l.contains('bi') && (l.contains('frente') || l.contains('front'))) {
    return 0;
  }
  if (l.contains('bi') &&
      (l.contains('verso') ||
          l.contains('traseiro') ||
          l.contains('tras') ||
          l.contains('back'))) {
    return 1;
  }
  if (l.contains('driving_license') || l.contains('carta')) return 2;
  if (l.contains('crlv') || l.contains('livrete')) return 3;
  if (l.contains('insurance') || l.contains('seguro')) return 4;
  if (l.contains('inspection') ||
      l.contains('inspecao') ||
      l.contains('inspeção') ||
      l.contains('vistoria')) {
    return 5;
  }
  if (l.contains('background')) return 6;
  return 10;
}

/// Verifica os documentos obrigatórios para aprovação (BI frente + verso).
Future<({bool hasBiFront, bool hasBiBack})> checkMandatoryDocs({
  required String driverId,
  String? userId,
  Map<String, dynamic>? docUrls,
}) async {
  final docs = await fetchDriverDocuments(
    driverId: driverId,
    userId: userId,
    docUrls: docUrls,
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
  final Map<String, dynamic>? docUrls;

  const DriverDocumentsSection({
    super.key,
    required this.driverId,
    this.userId,
    this.docUrls,
  });

  @override
  State<DriverDocumentsSection> createState() => _DriverDocumentsSectionState();
}

class _DriverDocumentsSectionState extends State<DriverDocumentsSection> {
  bool _loading = true;
  List<DriverDocFile> _docs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final res = await loadDriverDocuments(
      driverId: widget.driverId,
      userId: widget.userId,
      docUrls: widget.docUrls,
    );
    if (!mounted) return;
    setState(() {
      _docs = res.docs;
      _error = res.error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: KuponLoader(size: 56)),
      );
    }
    if (_error != null) {
      return _messageBox(
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFCF6679),
        text: _error!,
      );
    }
    if (_docs.isEmpty) {
      return _messageBox(
        icon: Icons.folder_off_outlined,
        color: AppTheme.onSurfaceVariant,
        text: 'Nenhum documento enviado por este motorista.',
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

  Widget _messageBox({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: color.withValues(alpha: 0.85),
              ),
            ),
          ),
          TextButton(
            onPressed: _load,
            child: Text(
              'Tentar novamente',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryContainer,
              ),
            ),
          ),
        ],
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
          doc.isPdf
              ? 'Use "Abrir no navegador" para ver este PDF.'
              : 'Pré-visualização indisponível',
          textAlign: TextAlign.center,
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

/// Diálogo autónomo com os documentos do motorista — usado na lista de
/// motoristas (ação "Documentos") para não obrigar a abrir o perfil.
Future<void> showDriverDocumentsDialog(
  BuildContext context, {
  required String driverId,
  String? userId,
  String? driverName,
  Map<String, dynamic>? docUrls,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppTheme.surfaceContainerLow,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_open_rounded,
                    color: AppTheme.primaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Documentos do motorista',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        if (driverName != null && driverName.isNotEmpty)
                          Text(
                            driverName,
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
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: DriverDocumentsSection(
                  driverId: driverId,
                  userId: userId,
                  docUrls: docUrls,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Fechar',
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

/// Diálogo de revisão antes de aprovar: mostra os documentos do
/// motorista e só depois permite aprovar.
Future<void> showDriverApprovalReview(
  BuildContext context, {
  required String driverId,
  required String? userId,
  required String driverName,
  required Future<void> Function() onApprove,
  Map<String, dynamic>? docUrls,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => _ApprovalReviewDialog(
      driverId: driverId,
      userId: userId,
      driverName: driverName,
      onApprove: onApprove,
      docUrls: docUrls,
    ),
  );
}

class _ApprovalReviewDialog extends StatefulWidget {
  final String driverId;
  final String? userId;
  final String driverName;
  final Future<void> Function() onApprove;
  final Map<String, dynamic>? docUrls;

  const _ApprovalReviewDialog({
    required this.driverId,
    required this.userId,
    required this.driverName,
    required this.onApprove,
    this.docUrls,
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
      docUrls: widget.docUrls,
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
                  const Icon(
                    Icons.pending_actions_rounded,
                    color: Color(0xFFF5C842),
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
                      docUrls: widget.docUrls,
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
                      onPressed: (_saving || _checkingDocs || !_docsOk)
                          ? null
                          : _approve,
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
