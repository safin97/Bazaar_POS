import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';

/// Currency display settings shared by Add market and the market Settings page.
class CurrencyDisplayFields extends StatelessWidget {
  const CurrencyDisplayFields({
    super.key,
    required this.currency,
    required this.enabled,
    required this.rate,
    required this.onChanged,
    this.onRateChanged,
  });

  final String currency;
  final bool enabled;
  final TextEditingController rate;
  final ValueChanged<bool> onChanged;
  final ValueChanged<String>? onRateChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      SwitchListTile.adaptive(
        key: const ValueKey('display-both-currencies'),
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr('displayBothCurrencies')),
        subtitle: Text(context.tr('displayBothCurrenciesHint')),
        value: enabled,
        onChanged: ['USD', 'IQD'].contains(currency) ? onChanged : null,
      ),
      if (enabled) ...[
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('usd-iqd-exchange-rate'),
          controller: rate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.tr('usdIqdExchangeRate'),
            helperText: context.tr('exchangeRateHint'),
            helperMaxLines: 4,
          ),
          validator: (value) {
            final parsed = parseMoney(value ?? '');
            return parsed == null || parsed <= 0
                ? context.tr('invalidExchangeRate')
                : null;
          },
          onChanged: onRateChanged,
        ),
        const SizedBox(height: 10),
        Text(
          '${context.tr('paymentsInMainCurrency')}: ${context.tr('currency$currency')}',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ],
  );
}
