import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/currency_display_fields.dart';
import '../widgets/receipt.dart';
import '../widgets/photo_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  Map<String, TextEditingController>? _controllers;
  Map<String, TextEditingController> get _c => _controllers!;
  String? _logo;
  String _currency = 'IQD';
  bool _displayBoth = false;
  final _rate = TextEditingController();
  int _width = 80;
  bool _showCashier = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllers != null) return;
    final s = context.store.settings;
    _controllers =
        {
          'name': s.name,
          'tagline': s.tagline,
          'address': s.address,
          'phone': s.phone,
          'tax': (s.taxBasisPoints / 100).toStringAsFixed(2),
          'header': s.receiptHeader,
          'footer': s.receiptFooter,
        }.map(
          (key, value) => MapEntry(
            key,
            TextEditingController(text: value)..addListener(_refresh),
          ),
        );
    _logo = s.logo;
    _currency = s.currency;
    _displayBoth = s.secondaryCurrency != null;
    _rate.text = s.usdToIqdRate == null
        ? ''
        : (s.usdToIqdRate! / 100).toStringAsFixed(2);
    _showCashier = s.showCashier;
    _width = s.receiptWidth;
  }

  void _refresh() => setState(() {});
  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _rate.dispose();
    super.dispose();
  }

  StoreSettings get _settings => StoreSettings(
    name: _c['name']!.text.trim(),
    tagline: _c['tagline']!.text.trim(),
    address: _c['address']!.text.trim(),
    phone: _c['phone']!.text.trim(),
    currency: _currency,
    usdToIqdRate: _displayBoth ? (parseMoney(_rate.text) ?? 0) : null,
    taxBasisPoints: parseMoney(_c['tax']!.text) ?? 0,
    receiptHeader: _c['header']!.text.trim(),
    receiptFooter: _c['footer']!.text.trim(),
    showCashier: _showCashier,
    logo: _logo,
    receiptWidth: _width,
  );
  Future<void> _pickLogo() async {
    try {
      final photo = await pickItemPhoto();
      if (mounted && photo != null) setState(() => _logo = photo);
    } catch (e) {
      if (mounted) notifyError(context, e);
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      context.store.saveSettings(_settings);
      notifySaved(context);
    } catch (e) {
      notifyError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final preview = Sale(
      id: 'preview',
      number: 'BZ-000001',
      createdAt: DateTime.now(),
      cashierId: 'preview',
      cashierName: store.currentUser!.name,
      lines: [
        SaleLine(
          productId: 'preview',
          name: translate(store.language, 'product'),
          quantity: 2,
          price: _currency == 'IQD' ? 250000 : 250,
          cost: 0,
        ),
      ],
      discount: 0,
      tax:
          ((_currency == 'IQD' ? 500000 : 500) * _settings.taxBasisPoints +
              5000) ~/
          10000,
      paymentMethod: 'cash',
      tendered:
          (_currency == 'IQD' ? 500000 : 500) +
          (((_currency == 'IQD' ? 500000 : 500) * _settings.taxBasisPoints +
                  5000) ~/
              10000),
      settings: _settings,
      language: store.language,
    );
    final form = Form(
      key: _form,
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('brand'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 23),
                  Wrap(
                    spacing: 18,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      BrandMark(size: 76, settings: _settings),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickLogo,
                            icon: const Icon(Icons.upload_outlined, size: 17),
                            label: Text(context.tr('uploadLogo')),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('photoHint'),
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                        ],
                      ),
                      if (_logo != null)
                        IconButton(
                          tooltip: context.tr('removeLogo'),
                          onPressed: () => setState(() => _logo = null),
                          icon: const Icon(Icons.delete_outline, color: danger),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Field(_c['name']!, 'storeName', required: true),
                  Field(_c['tagline']!, 'tagline'),
                  Field(_c['address']!, 'address', maxLines: 2),
                  Field(_c['phone']!, 'phone'),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      labelText: context.tr('mainCurrency'),
                      helperText: context.tr('currencyHint'),
                      helperMaxLines: 3,
                    ),
                    isExpanded: true,
                    items: ['IQD', 'USD', 'EUR']
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(context.tr('currency$c')),
                          ),
                        )
                        .toList(),
                    onChanged:
                        store.products.isNotEmpty || store.sales.isNotEmpty
                        ? null
                        : (v) => setState(() {
                            _currency = v!;
                            if (_currency == 'EUR') _displayBoth = false;
                          }),
                  ),
                  CurrencyDisplayFields(
                    currency: _currency,
                    enabled: _displayBoth,
                    rate: _rate,
                    onChanged: (value) => setState(() => _displayBoth = value),
                    onRateChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Field(_c['tax']!, 'taxRate', moneyValue: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('receiptSettings'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Field(_c['header']!, 'receiptHeader', maxLines: 2),
                  Field(_c['footer']!, 'receiptFooter', maxLines: 3),
                  DropdownButtonFormField<int>(
                    initialValue: _width,
                    decoration: InputDecoration(
                      labelText: context.tr('paperWidth'),
                    ),
                    items: [58, 80]
                        .map(
                          (w) =>
                              DropdownMenuItem(value: w, child: Text('$w mm')),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _width = v!),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _showCashier,
                    title: Text(
                      context.tr('showCashier'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onChanged: (v) => setState(() => _showCashier = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final paper = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.visibility_outlined, size: 16, color: muted),
            const SizedBox(width: 7),
            Text(
              context.tr('preview'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('previewHint'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 22),
        ReceiptPaper(sale: preview),
      ],
    );
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        PageHeading(
          title: 'settings',
          subtitle: 'settingsSubtitle',
          action: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(context.tr('save')),
          ),
        ),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth > 890
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: form),
                    const SizedBox(width: 32),
                    SizedBox(width: 360, child: paper),
                  ],
                )
              : Column(
                  children: [
                    form,
                    const SizedBox(height: 32),
                    paper,
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _save,
                      child: Text(context.tr('save')),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
