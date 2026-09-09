import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/currency_display_fields.dart';
import '../widgets/photo_picker.dart';

class MarketsScreen extends StatelessWidget {
  const MarketsScreen({super.key, required this.onOpen});
  final ValueChanged<String> onOpen;

  Future<void> _create(BuildContext context) async {
    final id = await showDialog<String>(
      context: context,
      builder: (_) => const _MarketEditor(),
    );
    if (id != null && context.mounted) onOpen(id);
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      PageHeading(
        title: 'markets',
        subtitle: 'marketsSubtitle',
        action: FilledButton.icon(
          key: const ValueKey('add-market'),
          onPressed: () => _create(context),
          icon: const Icon(Icons.add_business_outlined, size: 18),
          label: Text(context.tr('addMarket')),
        ),
      ),
      Text(context.tr('marketSetupHint'), style: const TextStyle(color: muted)),
      const SizedBox(height: 20),
      for (final market in context.store.markets) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BrandMark(settings: market.settings, size: 58),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            market.settings.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('currency${market.settings.currency}'),
                            style: const TextStyle(color: muted),
                          ),
                          if (market.settings.secondaryCurrency != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${context.tr('displayBothCurrencies')} · ${displayExchangeRate(market.settings)}',
                              style: const TextStyle(color: muted),
                            ),
                          ],
                          if (market.settings.address.isNotEmpty)
                            Text(market.settings.address),
                          if (market.settings.phone.isNotEmpty)
                            Text(market.settings.phone),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: ValueKey('open-market-${market.id}'),
                      onPressed: () => onOpen(market.id),
                      icon: const Icon(Icons.tune, size: 18),
                      label: Text(context.tr('manageMarket')),
                    ),
                    if (market.id == context.store.activeMarketId)
                      StatusPill(context.tr('currentMarket')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ],
  );
}

class _MarketEditor extends StatefulWidget {
  const _MarketEditor();
  @override
  State<_MarketEditor> createState() => _MarketEditorState();
}

class _MarketEditorState extends State<_MarketEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rate = TextEditingController();
  String _currency = 'USD';
  bool _displayBoth = false;
  String? _logo;
  bool _uploadingLogo = false;

  Future<void> _pickLogo() async {
    setState(() => _uploadingLogo = true);
    try {
      final photo = await pickItemPhoto();
      if (mounted && photo != null) setState(() => _logo = photo);
    } catch (error) {
      if (mounted) notifyError(context, error);
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }
  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      final id = context.store.createMarket(
        name: _name.text,
        currency: _currency,
        logo: _logo,
        usdToIqdRate: _displayBoth ? parseMoney(_rate.text) : null,
      );
      Navigator.pop(context, id);
    } catch (e) {
      notifyError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
    title: 'addMarket',
    onSave: _save,
    busy: _uploadingLogo,
    child: Form(
      key: _form,
      child: Column(
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BrandMark(size: 76, settings: StoreSettings(logo: _logo)),
              OutlinedButton.icon(
                key: const ValueKey('market-upload-logo'),
                onPressed: _uploadingLogo ? null : _pickLogo,
                icon: _uploadingLogo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_outlined, size: 18),
                label: Text(context.tr('uploadLogo')),
              ),
              if (_logo != null)
                IconButton(
                  key: const ValueKey('market-remove-logo'),
                  tooltip: context.tr('removeLogo'),
                  onPressed: _uploadingLogo
                      ? null
                      : () => setState(() => _logo = null),
                  icon: const Icon(Icons.delete_outline, color: danger),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(context.tr('photoHint'), style: const TextStyle(color: muted)),
          const SizedBox(height: 24),
          Field(_name, 'storeName', required: true),
          DropdownButtonFormField<String>(
            key: const ValueKey('market-main-currency'),
            initialValue: _currency,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('mainCurrency')),
            items: ['USD', 'IQD', 'EUR']
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(context.tr('currency$c')),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _currency = v!;
              if (_currency == 'EUR') _displayBoth = false;
            }),
          ),
          CurrencyDisplayFields(
            currency: _currency,
            enabled: _displayBoth,
            rate: _rate,
            onChanged: (value) => setState(() => _displayBoth = value),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('marketSetupHint'),
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    ),
  );
}
