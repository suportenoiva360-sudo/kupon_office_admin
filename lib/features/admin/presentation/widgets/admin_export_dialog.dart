import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/features/admin/services/dashboard_export_service.dart';

enum ExportFormat { pdf, csv }

class AdminExportReportDialog extends StatefulWidget {
  final DashboardReportData reportData;

  const AdminExportReportDialog({
    super.key,
    required this.reportData,
  });

  static Future<void> show(BuildContext context, DashboardReportData data) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => AdminExportReportDialog(reportData: data),
    );
  }

  @override
  State<AdminExportReportDialog> createState() => _AdminExportReportDialogState();
}

class _AdminExportReportDialogState extends State<AdminExportReportDialog> {
  ExportFormat _selectedFormat = ExportFormat.pdf;
  bool _exporting = false;

  Future<void> _handleExport() async {
    setState(() => _exporting = true);
    try {
      if (_selectedFormat == ExportFormat.pdf) {
        await DashboardExportService.exportPdf(
          context: context,
          data: widget.reportData,
        );
      } else {
        await DashboardExportService.exportCsv(
          context: context,
          data: widget.reportData,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2E2E2E), width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
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
                          'Exportar Relatório do Dashboard',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE5E2E1),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gere um sumário completo de métricas operacionais e financeiras.',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF888888)),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Format selector
              Text(
                'SELECIONE O FORMATO',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildFormatOption(
                      format: ExportFormat.pdf,
                      title: 'Documento PDF',
                      subtitle: 'Layout visual, impressão e gráficos',
                      icon: Icons.picture_as_pdf_rounded,
                      badge: 'Recomendado',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFormatOption(
                      format: ExportFormat.csv,
                      title: 'Ficheiro CSV',
                      subtitle: 'Compatível com Excel e Google Sheets',
                      icon: Icons.table_chart_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Summary preview
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF282828)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.checklist_rounded,
                          size: 16,
                          color: AppTheme.primaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Conteúdo incluído na exportação:',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE5E2E1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildCheckItem(
                      'KPIs: Receita (${widget.reportData.revenue30d} Kz), Corridas, Motoristas e Usuários',
                    ),
                    _buildCheckItem(
                      'Histórico Diário: ${widget.reportData.daily.length} registos de evolução',
                    ),
                    _buildCheckItem(
                      'Ranking: Top ${widget.reportData.leaderboard.length} motoristas com faturamento e notas',
                    ),
                    _buildCheckItem(
                      'Alertas: ${widget.reportData.alerts.length} ocorrências e alertas operacionais',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _exporting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      side: const BorderSide(color: Color(0xFF333333)),
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFCCCCCC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _exporting ? null : _handleExport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryContainer,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      minimumSize: const Size(160, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            _selectedFormat == ExportFormat.pdf
                                ? Icons.print_rounded
                                : Icons.download_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _exporting
                          ? 'A processar...'
                          : _selectedFormat == ExportFormat.pdf
                              ? 'Gerar e Imprimir PDF'
                              : 'Descarregar CSV',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatOption({
    required ExportFormat format,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
  }) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () => setState(() => _selectedFormat = format),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryContainer.withValues(alpha: 0.12)
              : const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryContainer : const Color(0xFF282828),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryContainer : const Color(0xFFAAAAAA),
                  size: 24,
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFFFFFFFF) : const Color(0xFFCCCCCC),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: Color(0xFF00E676),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: const Color(0xFFB0B0B0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
