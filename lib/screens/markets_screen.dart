import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

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
  String _currency = 'USD';
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      final id = context.store.createMarket(
        name: _name.text,
        currency: _currency,
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
    child: Form(
      key: _form,
      child: Column(
        children: [
          Field(_name, 'storeName', required: true),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('currency')),
            items: ['USD', 'IQD', 'EUR']
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(context.tr('currency$c')),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _currency = v!),
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
