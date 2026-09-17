import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:kupon_office_admin/repositories/dashboard_repository.dart';

class DashboardReportData {
  final String periodName;
  final DateTime generatedAt;
  final int revenue30d;
  final int prevRevenue30d;
  final int trips24h;
  final int prevTrips24h;
  final int onlineDrivers;
  final int approvedDrivers;
  final int pendingDrivers;
  final int activeUsers;
  final int newUsers30d;
  final int openTickets;
  final List<DailyPoint> daily;
  final List<DashAlert> alerts;
  final List<Map<String, dynamic>> leaderboard;

  const DashboardReportData({
    required this.periodName,
    required this.generatedAt,
    required this.revenue30d,
    required this.prevRevenue30d,
    required this.trips24h,
    required this.prevTrips24h,
    required this.onlineDrivers,
    required this.approvedDrivers,
    required this.pendingDrivers,
    required this.activeUsers,
    required this.newUsers30d,
    required this.openTickets,
    required this.daily,
    required this.alerts,
    required this.leaderboard,
  });
}

class DashboardExportService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _dayFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _fileDateFormat = DateFormat('yyyyMMdd_HHmm');

  /// Gera e abre a pré-visualização/impressão do relatório PDF.
  static Future<void> exportPdf({
    required BuildContext context,
    required DashboardReportData data,
  }) async {
    try {
      final pdfBytes = await generatePdfDocument(data);
      final filename = 'relatorio_kupon_${_fileDateFormat.format(data.generatedAt)}.pdf';

      await Printing.layoutPdf(
        name: filename,
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Gera os bytes do documento PDF completo
  static Future<Uint8List> generatePdfDocument(DashboardReportData data) async {
    final pdf = pw.Document(
      title: 'Relatório Executivo KupON',
      author: 'KupON Admin',
    );

    pw.Font fontRegular;
    pw.Font fontBold;

    try {
      fontRegular = await PdfGoogleFonts.spaceGroteskRegular();
      fontBold = await PdfGoogleFonts.spaceGroteskBold();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final primaryOrange = PdfColor.fromInt(0xFFFF6B00);
    final darkBg = PdfColor.fromInt(0xFF131313);
    final cardBg = PdfColor.fromInt(0xFF1F1F1F);
    final textWhite = PdfColor.fromInt(0xFFFFFFFF);
    final textMuted = PdfColor.fromInt(0xFFA0A0A0);
    final tableBorder = PdfColor.fromInt(0xFF2E2E2E);
    final lightGrey = PdfColor.fromInt(0xFF282828);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (context) => _buildPdfHeader(
          data: data,
          primaryColor: primaryOrange,
          textColor: textWhite,
          mutedColor: textMuted,
        ),
        footer: (context) => _buildPdfFooter(
          context: context,
          mutedColor: textMuted,
        ),
        build: (context) => [
          pw.SizedBox(height: 16),
          // ── KPI Summary Cards ──
          _buildPdfKpiGrid(
            data: data,
            primaryColor: primaryOrange,
            cardBg: cardBg,
            textColor: textWhite,
            mutedColor: textMuted,
          ),
          pw.SizedBox(height: 24),

          // ── Tabela Diária ──
          if (data.daily.isNotEmpty) ...[
            _buildSectionHeader('Histórico Diário Operacional', primaryOrange, textWhite),
            pw.SizedBox(height: 8),
            _buildDailyTable(data.daily, darkBg, lightGrey, textWhite, tableBorder),
            pw.SizedBox(height: 24),
          ],

          // ── Leaderboard / Top Motoristas ──
          if (data.leaderboard.isNotEmpty) ...[
            _buildSectionHeader('Ranking de Melhores Motoristas', primaryOrange, textWhite),
            pw.SizedBox(height: 8),
            _buildLeaderboardTable(data.leaderboard, darkBg, lightGrey, textWhite, tableBorder),
            pw.SizedBox(height: 24),
          ],

          // ── Alertas & Ocorrências ──
          if (data.alerts.isNotEmpty) ...[
            _buildSectionHeader('Alertas e Ocorrências Recentes', primaryOrange, textWhite),
            pw.SizedBox(height: 8),
            _buildAlertsTable(data.alerts, darkBg, lightGrey, textWhite, tableBorder),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfHeader({
    required DashboardReportData data,
    required PdfColor primaryColor,
    required PdfColor textColor,
    required PdfColor mutedColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey700, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 12,
                    height: 12,
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'KupON ADMIN',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Relatório Operacional & Financeiro',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Período: ${data.periodName}',
                style: pw.TextStyle(fontSize: 10, color: mutedColor),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Emitido em: ${_dateFormat.format(data.generatedAt)}',
                style: pw.TextStyle(fontSize: 9, color: mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter({
    required pw.Context context,
    required PdfColor mutedColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey800, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'KupON Tecnologia Lda • Documento Confidencial do Sistema',
            style: pw.TextStyle(fontSize: 8, color: mutedColor),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: mutedColor),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionHeader(String title, PdfColor accentColor, PdfColor textColor) {
    return pw.Row(
      children: [
        pw.Container(width: 4, height: 14, color: accentColor),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfKpiGrid({
    required DashboardReportData data,
    required PdfColor primaryColor,
    required PdfColor cardBg,
    required PdfColor textColor,
    required PdfColor mutedColor,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _buildKpiBox(
            label: 'RECEITA ESTIMADA',
            value: '${formatNumber(data.revenue30d)} Kz',
            subtext: 'Janela de 30 dias',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            accentColor: primaryColor,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildKpiBox(
            label: 'CORRIDAS REALIZADAS',
            value: '${data.trips24h}',
            subtext: 'Últimas 24 horas',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            accentColor: primaryColor,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildKpiBox(
            label: 'MOTORISTAS ATIVOS',
            value: '${data.onlineDrivers} / ${data.approvedDrivers}',
            subtext: '${data.pendingDrivers} pendentes aprovação',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            accentColor: primaryColor,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildKpiBox(
            label: 'BASE DE UTILIZADORES',
            value: '${data.activeUsers}',
            subtext: '+${data.newUsers30d} novos (30d)',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            accentColor: primaryColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildKpiBox({
    required String label,
    required String value,
    required String subtext,
    required PdfColor cardBg,
    required PdfColor textColor,
    required PdfColor mutedColor,
    required PdfColor accentColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: cardBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey800, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: mutedColor,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtext,
            style: pw.TextStyle(
              fontSize: 7,
              color: mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDailyTable(
    List<DailyPoint> daily,
    PdfColor headerBg,
    PdfColor rowBg,
    PdfColor textColor,
    PdfColor borderColor,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          children: [
            _cell('Data', isHeader: true, textColor: textColor),
            _cell('Corridas', isHeader: true, align: pw.TextAlign.center, textColor: textColor),
            _cell('Receita Estimada', isHeader: true, align: pw.TextAlign.right, textColor: textColor),
          ],
        ),
        for (var i = 0; i < daily.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isEven ? rowBg : headerBg),
            children: [
              _cell(_dayFormat.format(daily[i].date), textColor: textColor),
              _cell('${daily[i].trips}', align: pw.TextAlign.center, textColor: textColor),
              _cell('${formatNumber(daily[i].revenue)} Kz', align: pw.TextAlign.right, textColor: textColor),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildLeaderboardTable(
    List<Map<String, dynamic>> drivers,
    PdfColor headerBg,
    PdfColor rowBg,
    PdfColor textColor,
    PdfColor borderColor,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          children: [
            _cell('#', isHeader: true, align: pw.TextAlign.center, textColor: textColor),
            _cell('Motorista', isHeader: true, textColor: textColor),
            _cell('Categoria', isHeader: true, textColor: textColor),
            _cell('Avaliação', isHeader: true, align: pw.TextAlign.center, textColor: textColor),
            _cell('Corridas', isHeader: true, align: pw.TextAlign.center, textColor: textColor),
            _cell('Faturamento', isHeader: true, align: pw.TextAlign.right, textColor: textColor),
          ],
        ),
        for (var i = 0; i < drivers.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isEven ? rowBg : headerBg),
            children: [
              _cell('${i + 1}', align: pw.TextAlign.center, textColor: textColor),
              _cell(drivers[i]['name'] as String? ?? 'Motorista', textColor: textColor),
              _cell((drivers[i]['category'] as String? ?? 'Standard').toUpperCase(), textColor: textColor),
              _cell('${(drivers[i]['rating'] as num?)?.toStringAsFixed(1) ?? '5.0'} ★', align: pw.TextAlign.center, textColor: textColor),
              _cell('${drivers[i]['period_trips'] ?? 0}', align: pw.TextAlign.center, textColor: textColor),
              _cell('${formatNumber((drivers[i]['period_revenue'] as num?) ?? 0)} Kz', align: pw.TextAlign.right, textColor: textColor),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildAlertsTable(
    List<DashAlert> alerts,
    PdfColor headerBg,
    PdfColor rowBg,
    PdfColor textColor,
    PdfColor borderColor,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(4),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          children: [
            _cell('Tipo', isHeader: true, textColor: textColor),
            _cell('Título', isHeader: true, textColor: textColor),
            _cell('Descrição', isHeader: true, textColor: textColor),
            _cell('Data/Hora', isHeader: true, align: pw.TextAlign.right, textColor: textColor),
          ],
        ),
        for (var i = 0; i < alerts.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isEven ? rowBg : headerBg),
            children: [
              _cell(alerts[i].kind.toUpperCase(), textColor: textColor),
              _cell(alerts[i].title, textColor: textColor),
              _cell(alerts[i].description, textColor: textColor),
              _cell(alerts[i].time, align: pw.TextAlign.right, textColor: textColor),
            ],
          ),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    required PdfColor textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }

  /// Exporta os dados em formato CSV para download ou salvamento
  static Future<void> exportCsv({
    required BuildContext context,
    required DashboardReportData data,
  }) async {
    try {
      final rows = <List<dynamic>>[];

      // Cabeçalho Geral
      rows.add(['KupON ADMIN - RELATORIO OPERACIONAL E FINANCEIRO']);
      rows.add(['Periodo', data.periodName]);
      rows.add(['Data de Geracao', _dateFormat.format(data.generatedAt)]);
      rows.add([]);

      // Indicadores Chave
      rows.add(['--- METRICAS GERAIS (KPIs) ---']);
      rows.add(['Metrica', 'Valor', 'Observacao']);
      rows.add(['Receita Estimada (30d)', '${data.revenue30d} Kz', 'Historico recente']);
      rows.add(['Corridas (24h)', data.trips24h, 'Corridas criadas']);
      rows.add(['Motoristas Online', data.onlineDrivers, 'Conectados']);
      rows.add(['Motoristas Aprovados', data.approvedDrivers, 'Prontos para operar']);
      rows.add(['Motoristas Pendentes', data.pendingDrivers, 'Aguardam validacao']);
      rows.add(['Utilizadores Registados', data.activeUsers, 'Total de passageiros/usuarios']);
      rows.add(['Novos Registos (30d)', data.newUsers30d, 'Crescimento']);
      rows.add(['Tickets de Suporte Abertos', data.openTickets, 'Requerem suporte']);
      rows.add([]);

      // Histórico diário
      if (data.daily.isNotEmpty) {
        rows.add(['--- HISTORICO DIARIO DE CORRIDAS E RECEITA ---']);
        rows.add(['Data', 'Qtd Corridas', 'Receita Estimada (Kz)']);
        for (final p in data.daily) {
          rows.add([_dayFormat.format(p.date), p.trips, p.revenue]);
        }
        rows.add([]);
      }

      // Ranking de motoristas
      if (data.leaderboard.isNotEmpty) {
        rows.add(['--- TOP MOTORISTAS DO PERIODO ---']);
        rows.add(['Posicao', 'Motorista', 'Categoria', 'Avaliacao', 'Corridas Realizadas', 'Faturamento (Kz)']);
        for (var i = 0; i < data.leaderboard.length; i++) {
          final d = data.leaderboard[i];
          rows.add([
            i + 1,
            d['name'] ?? 'Motorista',
            (d['category'] ?? 'Standard').toString().toUpperCase(),
            (d['rating'] as num?)?.toStringAsFixed(1) ?? '5.0',
            d['period_trips'] ?? 0,
            d['period_revenue'] ?? 0,
          ]);
        }
        rows.add([]);
      }

      // Alertas
      if (data.alerts.isNotEmpty) {
        rows.add(['--- ALERTAS E OCORRENCIAS ---']);
        rows.add(['Tipo', 'Titulo', 'Descricao', 'Data/Hora']);
        for (final a in data.alerts) {
          rows.add([a.kind, a.title, a.description, a.time]);
        }
      }

      final csvString = csv.encode(rows);
      final bytes = Uint8List.fromList(utf8.encode(csvString));
      final filename = 'relatorio_kupon_${_fileDateFormat.format(data.generatedAt)}.csv';

      // Salva no sistema de ficheiros se suportado (Desktop / Linux)
      String? savedPath;
      if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
        try {
          final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(bytes);
          savedPath = file.path;
        } catch (_) {}
      }

      // Abre share dialog / download
      await Printing.sharePdf(bytes: bytes, filename: filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedPath != null
                  ? 'Ficheiro CSV guardado com sucesso em: $savedPath'
                  : 'Ficheiro CSV exportado com sucesso ($filename)',
            ),
            backgroundColor: const Color(0xFF00C853),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar CSV: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
