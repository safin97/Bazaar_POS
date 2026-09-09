import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/branding.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';

Future<void> saveBytes(
  BuildContext context,
  Uint8List bytes,
  String name,
  String extension,
) async {
  try {
    final path = await FilePicker.platform.saveFile(
      fileName: name,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
    if (path != null && context.mounted) notifySaved(context, 'fileSaved');
  } catch (e) {
    if (context.mounted) notifyError(context, e);
  }
}

Future<Uint8List> receiptPdf(Sale sale) async {
  final fonts = await Future.wait(
    [
      'NotoSans-Regular',
      'NotoSans-Bold',
      'NotoSansArabic-Regular',
      'NotoSansArabic-Bold',
    ].map(
      (f) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$f.ttf')),
    ),
  );
  final rtl = sale.language != 'en';
  final doc = pw.Document(
    title: sale.number,
    author: sale.settings.name,
    theme: pw.ThemeData.withFont(
      base: fonts[0],
      bold: fonts[1],
      fontFallback: [fonts[2], fonts[3]],
    ),
  );
  String t(String key) => translate(sale.language, key);
  String m(int n) => money(n, sale.settings.currency);
  final s = sale.settings;
  final logoBytes =
      s.logoBytes ??
      (await rootBundle.load(defaultLogoAsset)).buffer.asUint8List();
  pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          value,
          textDirection: pw.TextDirection.ltr,
          style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null),
        ),
      ],
    ),
  );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        s.receiptWidth * PdfPageFormat.mm,
        double.infinity,
        marginAll: 5 * PdfPageFormat.mm,
      ),
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      build: (_) => pw.DefaultTextStyle(
        style: const pw.TextStyle(fontSize: 8),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(logoBytes),
                width: 42,
                height: 42,
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              s.name,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            for (final text in [s.tagline, s.address, s.phone, s.receiptHeader])
              if (text.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(text, textAlign: pw.TextAlign.center),
                ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            row(t('receipt'), sale.number),
            pw.Text(
              dateLabel(sale.createdAt),
              textAlign: pw.TextAlign.center,
              textDirection: pw.TextDirection.ltr,
            ),
            if (s.showCashier) row(t('cashier'), sale.cashierName),
            pw.Divider(),
            for (final item in sale.lines) ...[
              pw.Text(
                item.name,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              row('${item.quantity} × ${m(item.price)}', m(item.total)),
              pw.SizedBox(height: 4),
            ],
            pw.Divider(),
            row(t('subtotal'), m(sale.subtotal)),
            if (sale.discount > 0) row(t('discount'), '-${m(sale.discount)}'),
            row(t('tax'), m(sale.tax)),
            row(t('total'), m(sale.total), bold: true),
            if (secondaryMoney(sale.total, s) case final reference?) ...[
              row(t('referenceTotal'), reference),
              pw.Text(
                '${displayExchangeRate(s)} · ${t('displayOnly')}',
                style: const pw.TextStyle(fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
            ],
            pw.Divider(),
            row(t('payment'), t(sale.paymentMethod)),
            row(t('amountReceived'), m(sale.tendered)),
            row(t('change'), m(sale.change)),
            if (sale.voided) ...[
              pw.Divider(),
              pw.Text(
                t('voided'),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(sale.voidReason),
            ],
            pw.SizedBox(height: 12),
            pw.Text(s.receiptFooter, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: sale.number,
                width: 120,
                height: 26,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              sale.number,
              textAlign: pw.TextAlign.center,
              textDirection: pw.TextDirection.ltr,
            ),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}

Future<void> showReceipt(BuildContext context, Sale sale) => showDialog<void>(
  context: context,
  builder: (context) => _ReceiptDialog(sale: sale),
);

class ReceiptPaper extends StatelessWidget {
  const ReceiptPaper({super.key, required this.sale});
  final Sale sale;
  @override
  Widget build(BuildContext context) {
    final s = sale.settings;
    String t(String key) => translate(sale.language, key);
    String m(int value) => money(value, s.currency);
    Widget row(String key, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(t(key))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                fontSize: bold ? 18 : 11,
              ),
            ),
          ),
        ],
      ),
    );
    return Directionality(
      textDirection: sale.language == 'en'
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: Container(
        width: s.receiptWidth == 58 ? 280 : 340,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: ink.withValues(alpha: .05),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoArabic'],
            color: ink,
            fontSize: 11,
            height: 1.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: BrandMark(settings: s, size: 42)),
              const SizedBox(height: 14),
              Text(
                s.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final text in [
                s.tagline,
                s.address,
                s.phone,
                s.receiptHeader,
              ])
                if (text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(text, textAlign: TextAlign.center),
                  ),
              const SizedBox(height: 12),
              const Divider(),
              row('receipt', sale.number),
              Text(dateLabel(sale.createdAt), textAlign: TextAlign.center),
              if (s.showCashier) row('cashier', sale.cashierName),
              const Divider(),
              for (final item in sale.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text('${item.quantity} × ${m(item.price)}'),
                          ),
                          Text(m(item.total)),
                        ],
                      ),
                    ],
                  ),
                ),
              const Divider(),
              row('subtotal', m(sale.subtotal)),
              if (sale.discount > 0) row('discount', '-${m(sale.discount)}'),
              row('tax', m(sale.tax)),
              row('total', m(sale.total), bold: true),
              if (secondaryMoney(sale.total, s) case final reference?) ...[
                row('referenceTotal', reference),
                Text(
                  '${displayExchangeRate(s)} · ${t('displayOnly')}',
                  style: const TextStyle(fontSize: 10, color: muted),
                  textAlign: TextAlign.center,
                ),
              ],
              const Divider(),
              row('payment', t(sale.paymentMethod)),
              row('amountReceived', m(sale.tendered)),
              row('change', m(sale.change)),
              if (sale.voided) ...[
                const Divider(),
                Text(
                  t('voided'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(sale.voidReason),
              ],
              const SizedBox(height: 20),
              Text(s.receiptFooter, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              const Icon(Icons.receipt_long_rounded, size: 32, color: muted),
              const SizedBox(height: 4),
              Text(sale.number, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptDialog extends StatefulWidget {
  const _ReceiptDialog({required this.sale});
  final Sale sale;
  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  bool _busy = false;
  Future<void> _output(bool print) async {
    setState(() => _busy = true);
    try {
      final bytes = await receiptPdf(widget.sale);
      if (print) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: widget.sale.number,
          format: PdfPageFormat(
            widget.sale.settings.receiptWidth * PdfPageFormat.mm,
            297 * PdfPageFormat.mm,
          ),
          dynamicLayout: false,
        );
      } else if (mounted) {
        await saveBytes(context, bytes, '${widget.sale.number}.pdf', 'pdf');
      }
    } catch (e) {
      if (mounted) notifyError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 450,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('receipt'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ReceiptPaper(sale: widget.sale),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _output(false),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(context.tr('savePdf')),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _output(true),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: Text(context.tr('printReceipt')),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
