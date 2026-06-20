import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border;
import '../../core/constants/app_constants.dart';
import '../../core/utils/file_download.dart';
import '../../core/ads/interstitial_ad_manager.dart';
import '../../core/ads/banner_ad_widget.dart';
import '../../data/models/bill_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/reports_repository.dart';

class ReportsScreen extends StatefulWidget {
  final String societyId;
  final String societyName;

  const ReportsScreen({
    super.key,
    required this.societyId,
    required this.societyName,
  });

  @override
  State<ReportsScreen> createState() =>
      _ReportsScreenState();
}

class _ReportsScreenState
    extends State<ReportsScreen> {
  final _repo = ReportsRepository();
  late String _selectedMonth;
  bool _loading     = false;
  bool _exporting   = false;
  Map<String, dynamic>? _data;
  String? _error;
  final _interstitial = InterstitialAdManager();

  @override
  void initState() {
    super.initState();
    _selectedMonth = _currentMonth();
    _loadData();
    _interstitial.load();
  }

  @override
  void dispose() {
    _interstitial.dispose();
    super.dispose();
  }

  String _currentMonth() {
    final now    = DateTime.now();
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  List<String> get _months {
    const m = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i);
      return '${m[d.month - 1]}-${d.year}';
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error   = null;
      _data    = null;
    });
    try {
      final data = await _repo.buildReportData(
        societyId:   widget.societyId,
        month:       _selectedMonth,
        societyName: widget.societyName,
      );
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _fmt(double v) =>
      NumberFormat('#,##0').format(v);

  // ── Generate PDF ────────────────────────────────
  Future<File?> _generatePDF() async {
    final d        = _data!;
    final pdf      = pw.Document();
    final bills    = d['bills'] as List<BillModel>;
    final expenses =
    d['expenses'] as List<ExpenseModel>;

    final headerStyle = pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize:   10,
        color:      PdfColors.white);
    final cellStyle =
    const pw.TextStyle(fontSize: 9);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [

        // ── Report Header ────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius:
              pw.BorderRadius.circular(8)),
          child: pw.Column(
            crossAxisAlignment:
            pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SocietyPay',
                  style: pw.TextStyle(
                      color:      PdfColors.white,
                      fontSize:   22,
                      fontWeight:
                      pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                  d['societyName'] as String,
                  style: const pw.TextStyle(
                      color:   PdfColors.grey300,
                      fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Text(
                  'Monthly Report — '
                      '${d['month']}',
                  style: pw.TextStyle(
                      color:      PdfColors.amber,
                      fontSize:   14,
                      fontWeight:
                      pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                  'Generated: '
                      '${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: const pw.TextStyle(
                      color:   PdfColors.grey500,
                      fontSize: 9)),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // ── Financial Summary ────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius:
              pw.BorderRadius.circular(6)),
          child: pw.Row(
            mainAxisAlignment:
            pw.MainAxisAlignment.spaceAround,
            children: [
              _pdfStat('Total Billed',
                  '₹${_fmt(d['totalBilled'])}'),
              _pdfStat('Collected',
                  '₹${_fmt(d['totalCollected'])}'),
              _pdfStat('Pending',
                  '₹${_fmt(d['totalPending'])}'),
              _pdfStat('Expenses',
                  '₹${_fmt(d['totalExpenses'])}'),
              _pdfStat('Corpus',
                  '₹${_fmt(d['corpusBalance'])}'),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // ── Billing Table ────────────────────────
        pw.Text('Per Flat Payment Status',
            style: pw.TextStyle(
                fontSize:   14,
                fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),

        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800),
              children: [
                'Flat', 'Type', 'Amount',
                'Status', 'Paid On',
              ].map((h) => pw.Padding(
                  padding:
                  const pw.EdgeInsets.all(6),
                  child: pw.Text(h,
                      style: headerStyle)))
                  .toList(),
            ),
            ...bills.map((b) => pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: b.isPaid
                      ? PdfColors.green50
                      : PdfColors.red50),
              children: [
                _pdfCell(b.flatNumber,
                    cellStyle),
                _pdfCell(b.flatTypeName,
                    cellStyle),
                _pdfCell(
                    '₹${_fmt(b.totalAmount)}',
                    cellStyle),
                _pdfCell(
                    b.isPaid ? 'PAID' : 'UNPAID',
                    cellStyle),
                _pdfCell(b.paidAt != null
                    ? DateFormat('d MMM')
                    .format(b.paidAt!)
                    : '—',
                    cellStyle),
              ],
            )),
          ],
        ),

        pw.SizedBox(height: 20),

        // ── Expense Table ────────────────────────
        if (expenses.isNotEmpty) ...[
          pw.Text('Approved Expenses',
              style: pw.TextStyle(
                  fontSize:   14,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration:
                const pw.BoxDecoration(
                    color:
                    PdfColors.blueGrey800),
                children: [
                  'Description', 'Category',
                  'Amount', 'Corpus?',
                ].map((h) => pw.Padding(
                    padding:
                    const pw.EdgeInsets.all(6),
                    child: pw.Text(h,
                        style: headerStyle)))
                    .toList(),
              ),
              ...expenses.map((e) =>
                  pw.TableRow(children: [
                    _pdfCell(e.description,
                        cellStyle),
                    _pdfCell(e.categoryLabel,
                        cellStyle),
                    _pdfCell(
                        '₹${_fmt(e.amount)}',
                        cellStyle),
                    _pdfCell(
                        e.isCorpusDeduction
                            ? 'Yes' : 'No',
                        cellStyle),
                  ])),
            ],
          ),
        ],

        pw.SizedBox(height: 20),

        // ── Summary Footer ───────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius:
              pw.BorderRadius.circular(6)),
          child: pw.Column(children: [
            _pdfSummaryRow(
                'Total Collected',
                '₹${_fmt(d['totalCollected'])}',
                PdfColors.green800),
            _pdfSummaryRow(
                'Operational Expenses',
                '- ₹${_fmt(d['opExpenses'])}',
                PdfColors.red800),
            _pdfSummaryRow(
                'Net Surplus / Deficit',
                '${(d['surplus'] as double) >= 0 ? '+' : '-'} ₹${_fmt((d['surplus'] as double).abs())}',
                (d['surplus'] as double) >= 0
                    ? PdfColors.green800
                    : PdfColors.red800),
          ]),
        ),

        pw.SizedBox(height: 20),
        pw.Divider(),
        pw.Center(child: pw.Text(
            'SocietyPay | Making Society Management Simple',
            style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey500))),
      ],
    ));

    final bytes = await pdf.save();

    if (kIsWeb) {
      // Web: trigger browser download directly
      triggerWebDownload(
        'societypay_report_$_selectedMonth.pdf',
        bytes,
        'application/pdf',
      );
      return null;
    }

    final dir  = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/societypay_report'
        '_${_selectedMonth}.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  pw.Widget _pdfStat(
      String label, String value) =>
      pw.Column(
        crossAxisAlignment:
        pw.CrossAxisAlignment.center,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize:   11,
                  fontWeight: pw.FontWeight.bold,
                  color:      PdfColors.blue900)),
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 8,
                  color:    PdfColors.blue700)),
        ],
      );

  pw.Widget _pdfCell(
      String text, pw.TextStyle style) =>
      pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(text, style: style));

  pw.Widget _pdfSummaryRow(
      String label, String value, PdfColor color) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
            vertical: 4),
        child: pw.Row(
          mainAxisAlignment:
          pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 11)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize:   12,
                    fontWeight: pw.FontWeight.bold,
                    color:      color)),
          ],
        ),
      );

  // ── Generate Excel ──────────────────────────────
  Future<File?> _generateExcel() async {
    final d        = _data!;
    final bills    = d['bills'] as List<BillModel>;
    final expenses =
    d['expenses'] as List<ExpenseModel>;
    final excel    = Excel.createExcel();

    // ── Summary Sheet ────────────────────────────
    final summary  = excel['Summary'];
    summary.appendRow([
      TextCellValue('SocietyPay — Monthly Report'),
    ]);
    summary.appendRow([
      TextCellValue(
          '${d['societyName']} — ${d['month']}'),
    ]);
    summary.appendRow([TextCellValue('')]);
    summary.appendRow([
      TextCellValue('Total Billed'),
      DoubleCellValue(d['totalBilled']),
    ]);
    summary.appendRow([
      TextCellValue('Total Collected'),
      DoubleCellValue(d['totalCollected']),
    ]);
    summary.appendRow([
      TextCellValue('Total Pending'),
      DoubleCellValue(d['totalPending']),
    ]);
    summary.appendRow([
      TextCellValue('Total Expenses'),
      DoubleCellValue(d['totalExpenses']),
    ]);
    summary.appendRow([
      TextCellValue('Corpus Balance'),
      DoubleCellValue(d['corpusBalance']),
    ]);
    summary.appendRow([
      TextCellValue('Net Surplus'),
      DoubleCellValue(d['surplus']),
    ]);

    // ── Billing Sheet ────────────────────────────
    final billing = excel['Billing'];
    billing.appendRow([
      TextCellValue('Flat Number'),
      TextCellValue('Flat Type'),
      TextCellValue('Fixed Amount'),
      TextCellValue('Variable Amount'),
      TextCellValue('Total Amount'),
      TextCellValue('Status'),
      TextCellValue('Paid On'),
      TextCellValue('Resident'),
    ]);
    for (final b in bills) {
      billing.appendRow([
        TextCellValue(b.flatNumber),
        TextCellValue(b.flatTypeName),
        DoubleCellValue(b.fixedAmount),
        DoubleCellValue(b.variableAmount),
        DoubleCellValue(b.totalAmount),
        TextCellValue(b.isPaid
            ? 'PAID' : 'UNPAID'),
        TextCellValue(b.paidAt != null
            ? DateFormat('dd/MM/yyyy')
            .format(b.paidAt!)
            : '—'),
        TextCellValue(
            b.billingResponsibleName),
      ]);
    }

    // ── Expenses Sheet ───────────────────────────
    final expSheet = excel['Expenses'];
    expSheet.appendRow([
      TextCellValue('Description'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Corpus Deduction'),
      TextCellValue('Added By'),
      TextCellValue('Date'),
    ]);
    for (final e in expenses) {
      expSheet.appendRow([
        TextCellValue(e.description),
        TextCellValue(e.categoryLabel),
        DoubleCellValue(e.amount),
        TextCellValue(e.isCorpusDeduction
            ? 'Yes' : 'No'),
        TextCellValue(e.addedByName),
        TextCellValue(DateFormat('dd/MM/yyyy')
            .format(e.createdAt)),
      ]);
    }

    final bytes = excel.encode()!;

    if (kIsWeb) {
      // Web: trigger browser download directly
      triggerWebDownload(
        'societypay_report_$_selectedMonth.xlsx',
        bytes,
        'application/vnd.openxmlformats-officedocument'
            '.spreadsheetml.sheet',
      );
      return null;
    }

    final dir  = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/societypay_report'
        '_${_selectedMonth}.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      // On web: generate* triggers browser download
      // and returns null — no share step needed.
      final File? file;
      if (format == 'pdf') {
        file = await _generatePDF();
      } else {
        file = await _generateExcel();
      }

      if (!kIsWeb && file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'SocietyPay Report — $_selectedMonth',
        );
        // Show an interstitial after the report is shared
        _interstitial.showThen(() {});
      }

      if (mounted && kIsWeb) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text(
                '✅ Download started'),
            backgroundColor:
            AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor:
            AppColors.danger));
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BannerAdWidget(),
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Month selector
          Padding(
            padding: const EdgeInsets.only(
                right: 8),
            child: DropdownButton<String>(
              value: _selectedMonth,
              dropdownColor:
              AppColors.primaryDark,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              iconEnabledColor: Colors.white,
              underline: const SizedBox(),
              items: _months.map((m) =>
                  DropdownMenuItem(
                      value: m,
                      child: Text(m))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(
                          () => _selectedMonth = v);
                  _loadData();
                }
              },
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                  color: AppColors.primary),
              SizedBox(height: 16),
              Text('Building report...',
                  style: TextStyle(
                      color:
                      AppColors.textSecondary)),
            ],
          ))
          : _error != null
          ? Center(
          child: Padding(
            padding:
            const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 48),
                const SizedBox(height: 16),
                Text(_error!,
                    textAlign:
                    TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.danger)),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: _loadData,
                    child: const Text(
                        'Retry')),
              ],
            ),
          ))
          : _data == null
          ? const Center(
          child: Text('No data'))
          : ListView(
        padding:
        const EdgeInsets.all(16),
        children: [

          // ── Financial Summary ──────────
          _SectionTitle(
              '📊 Financial Summary — '
                  '$_selectedMonth'),
          const SizedBox(height: 10),
          _SummaryCard(data: _data!),

          const SizedBox(height: 16),

          // ── Collection Progress ────────
          _SectionTitle(
              '🏠 Collection Status'),
          const SizedBox(height: 10),
          _CollectionCard(
              data: _data!),

          const SizedBox(height: 16),

          // ── Expense Breakdown ──────────
          _SectionTitle(
              '💸 Expense Breakdown'),
          const SizedBox(height: 10),
          _ExpenseCard(data: _data!),

          const SizedBox(height: 16),

          // ── Export buttons ─────────────
          _SectionTitle('📤 Export'),
          const SizedBox(height: 10),
          _ExportCard(
            month:     _selectedMonth,
            exporting: _exporting,
            onExport:  _export,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Report Widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) =>
      Text(title, style: AppText.h4);
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryCard({required this.data});

  String _fmt(double v) =>
      NumberFormat('#,##0').format(v);

  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: _SummaryBox(
                label: 'Total Billed',
                value:
                '₹${_fmt(data['totalBilled'])}',
                color: AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: _SummaryBox(
                label: 'Collected',
                value:
                '₹${_fmt(data['totalCollected'])}',
                color: AppColors.success)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _SummaryBox(
                label: 'Pending',
                value:
                '₹${_fmt(data['totalPending'])}',
                color: AppColors.danger)),
            const SizedBox(width: 10),
            Expanded(child: _SummaryBox(
                label: 'Net Surplus',
                value:
                '${(data['surplus'] as double) >= 0 ? '+' : ''}₹${_fmt(data['surplus'])}',
                color: (data['surplus'] as double)
                    >= 0
                    ? AppColors.success
                    : AppColors.danger)),
          ]),
          const Divider(height: 20),
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              const Text('Corpus Balance',
                  style: AppText.bodyBold),
              Text(
                  '₹${_fmt(data['corpusBalance'])}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
        ]),
      ));
}

class _SummaryBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: color.withOpacity(0.2))),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted)),
          ],
        ),
      );
}

class _CollectionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CollectionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final total   = data['totalFlats'] as int;
    final paid    = data['paidCount']  as int;
    final unpaid  = data['unpaidCount'] as int;
    final pct     = total == 0
        ? 0.0 : paid / total;

    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
          children: [
            Text('$paid / $total flats paid',
                style: AppText.bodyBold),
            Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor:
              AppColors.dangerLight,
              valueColor:
              const AlwaysStoppedAnimation(
                  AppColors.success)),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceAround,
          children: [
            _CollectionChip(
                label: 'Paid',
                count: paid,
                color: AppColors.success),
            _CollectionChip(
                label: 'Unpaid',
                count: unpaid,
                color: AppColors.danger),
          ],
        ),
      ]),
    ));
  }
}

class _CollectionChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CollectionChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color)),
        ]),
      );
}

class _ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ExpenseCard({required this.data});

  String _fmt(double v) =>
      NumberFormat('#,##0').format(v);

  @override
  Widget build(BuildContext context) {
    final expenses = data['expenses']
    as List<ExpenseModel>;

    if (expenses.isEmpty) {
      return Card(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text(
            'No expenses for ${data['month']}',
            style: const TextStyle(
                color: AppColors.textMuted))),
      ));
    }

    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        ...expenses.map((e) => Padding(
          padding: const EdgeInsets.only(
              bottom: 10),
          child: Row(children: [
            Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius:
                    BorderRadius.circular(10)),
                child: Center(child: Text(
                    e.categoryIcon,
                    style: const TextStyle(
                        fontSize: 18)))),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(e.description,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                        AppColors.textPrimary),
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis),
                Text(e.categoryLabel,
                    style: const TextStyle(
                        fontSize: 10,
                        color:
                        AppColors.textMuted)),
              ],
            )),
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Text(
                    '₹${_fmt(e.amount)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color:
                        AppColors.textPrimary)),
                if (e.isCorpusDeduction)
                  Container(
                      padding:
                      const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1),
                      decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius:
                          BorderRadius.circular(
                              10)),
                      child: const Text('CORPUS',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger))),
              ],
            ),
          ]),
        )),
        const Divider(height: 16),
        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Expenses',
                style: AppText.bodyBold),
            Text(
                '₹${_fmt(data['totalExpenses'])}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger)),
          ],
        ),
      ]),
    ));
  }
}

class _ExportCard extends StatelessWidget {
  final String month;
  final bool exporting;
  final void Function(String) onExport;

  const _ExportCard({
    required this.month,
    required this.exporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
                'Export report for $month',
                style: AppText.body),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: exporting
                    ? null
                    : () => onExport('pdf'),
                icon: exporting
                    ? const SizedBox(
                    width: 16, height: 16,
                    child:
                    CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : const Icon(
                    Icons.picture_as_pdf),
                label: const Text('PDF'),
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.danger),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: exporting
                    ? null
                    : () => onExport('excel'),
                icon: exporting
                    ? const SizedBox(
                    width: 16, height: 16,
                    child:
                    CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : const Icon(Icons.table_chart),
                label: const Text('Excel'),
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.success),
              )),
            ]),
            const SizedBox(height: 10),
            const Text(
                'Reports are shared via your '
                    'device share menu.',
                style: AppText.small),
          ],
        ),
      ));
}