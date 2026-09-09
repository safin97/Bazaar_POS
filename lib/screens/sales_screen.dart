import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/receipt.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _period = 'allTime', _query = '';
  String? _currency;
  DateTimeRange? _range;
  List<Sale> _filter(List<Sale> sales) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (_period) {
      'today' => today,
      'week' => today.subtract(const Duration(days: 6)),
      'month' => DateTime(now.year, now.month),
      'custom' => _range?.start,
      _ => null,
    };
    final end = _period == 'custom' && _range != null
        ? DateTime(_range!.end.year, _range!.end.month, _range!.end.day + 1)
        : null;
    return sales
        .where(
          (s) =>
              (start == null || !s.createdAt.isBefore(start)) &&
              (end == null || s.createdAt.isBefore(end)) &&
              '${s.number} ${s.cashierName} ${s.lines.map((line) => line.name).join(' ')}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
  }

  Future<void> _dates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      locale: Locale(
        context.store.language == 'ku' ? 'ar' : context.store.language,
      ),
    );
    if (range != null && mounted) {
      setState(() {
        _range = range;
        _period = 'custom';
      });
    }
  }

  Future<void> _void(Sale s) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _VoidDialog(),
    );
    if (reason != null && mounted) {
      try {
        context.store.voidSale(s.id, reason);
        notifySaved(context);
      } catch (e) {
        notifyError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final currencies = {
      store.settings.currency,
      ...store.visibleSales.map((sale) => sale.settings.currency),
    }.toList()..sort();
    final currency = currencies.contains(_currency)
        ? _currency!
        : store.settings.currency;
    final sales = _filter(
      store.visibleSales
          .where((sale) => sale.settings.currency == currency)
          .toList(),
    );
    final completed = sales.where((s) => !s.voided).toList();
    final revenue = completed.fold(
      0,
      (sum, s) => sum + s.subtotal - s.discount,
    );
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        PageHeading(
          title: 'sales',
          subtitle: 'salesSubtitle',
          action: store.canViewReports
              ? OutlinedButton.icon(
                  onPressed: () => saveBytes(
                    context,
                    Uint8List.fromList([
                      0xef,
                      0xbb,
                      0xbf,
                      ...utf8.encode(store.exportSalesCsv(sales)),
                    ]),
                    'bazaar-sales.csv',
                    'csv',
                  ),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(context.tr('export')),
                )
              : null,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final period in ['allTime', 'today', 'week', 'month'])
              ChoiceChip(
                label: Text(context.tr(period)),
                selected: _period == period,
                onSelected: (_) => setState(() => _period = period),
              ),
            ActionChip(
              avatar: const Icon(Icons.date_range_outlined, size: 16),
              label: Text(
                _period == 'custom'
                    ? '${DateFormat('dd/MM/yyyy').format(_range!.start)} – ${DateFormat('dd/MM/yyyy').format(_range!.end)}'
                    : context.tr('custom'),
              ),
              onPressed: _dates,
            ),
            if (currencies.length > 1)
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(currency),
                  initialValue: currency,
                  decoration: InputDecoration(
                    labelText: context.tr('selectReportCurrency'),
                    isDense: true,
                  ),
                  items: currencies
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _currency = value),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: c.maxWidth < 600 ? c.maxWidth : (c.maxWidth - 32) / 3,
                child: MetricCard(
                  label: 'revenue',
                  value: money(revenue, currency),
                  icon: Icons.payments_outlined,
                ),
              ),
              SizedBox(
                width: c.maxWidth < 600 ? c.maxWidth : (c.maxWidth - 32) / 3,
                child: MetricCard(
                  label: 'transactions',
                  value: '${completed.length}',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              SizedBox(
                width: c.maxWidth < 600 ? c.maxWidth : (c.maxWidth - 32) / 3,
                child: MetricCard(
                  label: 'averageSale',
                  value: money(
                    completed.isEmpty
                        ? 0
                        : (revenue / completed.length).round(),
                    currency,
                  ),
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: context.tr('search'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 20),
        if (sales.isEmpty)
          const EmptyState(icon: Icons.receipt_long_outlined)
        else
          Card(
            child: Column(
              children: sales
                  .map(
                    (s) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: s.voided
                              ? danger.withValues(alpha: .08)
                              : sage,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                          color: s.voided ? danger : forest,
                        ),
                      ),
                      title: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            s.number,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          StatusPill(
                            context.tr(s.voided ? 'voided' : 'completed'),
                            color: s.voided ? danger : forest,
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${dateLabel(s.createdAt)}\n${s.cashierName} · ${money(s.total, s.settings.currency)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: muted,
                          height: 1.7,
                        ),
                      ),
                      isThreeLine: true,
                      onTap: () => showReceipt(context, s),
                      trailing: PopupMenuButton<String>(
                        onSelected: (a) =>
                            a == 'receipt' ? showReceipt(context, s) : _void(s),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'receipt',
                            child: Text(context.tr('receipt')),
                          ),
                          if (store.canVoidSales && !s.voided)
                            PopupMenuItem(
                              value: 'void',
                              child: Text(
                                context.tr('voidSale'),
                                style: const TextStyle(color: danger),
                              ),
                            ),
                        ],
                        icon: const Icon(Icons.more_horiz, color: muted),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _VoidDialog extends StatefulWidget {
  const _VoidDialog();
  @override
  State<_VoidDialog> createState() => _VoidDialogState();
}

class _VoidDialogState extends State<_VoidDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr('voidSale')),
    content: SizedBox(
      width: 360,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('voidHint'), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 20),
            Field(_reason, 'voidReason', required: true, maxLines: 2),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('cancel')),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _reason.text.trim());
          }
        },
        child: Text(context.tr('voidSale')),
      ),
    ],
  );
}
