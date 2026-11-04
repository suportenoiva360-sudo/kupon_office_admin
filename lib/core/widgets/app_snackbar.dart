import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';

/// Tipo semântico de um snackbar do painel de administração.
enum AdminSnackType { success, error, warning, info }

const Color _kSuccess = Color(0xFF4CAF88);
const Color _kError = Color(0xFFCF6679);
const Color _kWarning = Color(0xFFE0A93E);
const Color _kInfo = Color(0xFF6EA8FE);

OverlayEntry? _activeEntry;
Timer? _activeTimer;

void _dismissActive() {
  _activeTimer?.cancel();
  _activeTimer = null;
  _activeEntry?.remove();
  _activeEntry = null;
}

/// Fecha o snackbar atualmente visível, se existir.
void hideAdminSnackBar() => _dismissActive();

/// Snackbar padronizado do painel de administração.
///
/// Desenhado no overlay raiz para ficar sempre acima de diálogos, sheets e
/// rotas. Mostra ícone com cor semântica, etiqueta de estado (Sucesso, Erro,
/// Atenção, Informação), mensagem e ação opcional.
void showAdminSnackBar(
  BuildContext context, {
  required String message,
  AdminSnackType type = AdminSnackType.info,
  String? title,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final (Color accent, IconData icon, String defaultTitle) = switch (type) {
    AdminSnackType.success => (
      _kSuccess,
      Icons.check_circle_rounded,
      'Sucesso',
    ),
    AdminSnackType.error => (_kError, Icons.error_rounded, 'Erro'),
    AdminSnackType.warning => (
      _kWarning,
      Icons.warning_amber_rounded,
      'Atenção',
    ),
    AdminSnackType.info => (_kInfo, Icons.info_rounded, 'Informação'),
  };

  final overlay = Overlay.of(context, rootOverlay: true);
  final media = MediaQuery.of(overlay.context);
  final isWide = media.size.width >= 720;

  _dismissActive();

  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: isWide ? null : 16,
      right: 16,
      width: isWide ? 400 : null,
      bottom: 20 + media.padding.bottom,
      child: _AdminToastView(
        message: message,
        title: title ?? defaultTitle,
        accent: accent,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                onAction();
                _dismissActive();
              },
        onClose: _dismissActive,
      ),
    ),
  );

  _activeEntry = entry;
  overlay.insert(entry);

  _activeTimer = Timer(
    duration ?? Duration(seconds: type == AdminSnackType.error ? 6 : 4),
    _dismissActive,
  );
}

class _AdminToastView extends StatelessWidget {
  const _AdminToastView({
    required this.message,
    required this.title,
    required this.accent,
    required this.icon,
    required this.onClose,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String title;
  final Color accent;
  final IconData icon;
  final VoidCallback onClose;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  accent.withValues(alpha: 0.10),
                  AppTheme.surfaceContainerHigh,
                ),
                AppTheme.surfaceContainerHigh,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.38), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Barra de acento lateral.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: accent),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            message,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          if (onAction != null && actionLabel != null) ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: onAction,
                              style: TextButton.styleFrom(
                                foregroundColor: accent,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(
                                actionLabel!,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded, size: 17),
                      color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
