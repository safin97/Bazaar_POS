import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/receipt.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key, required this.navigate});
  final ValueChanged<String> navigate;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  String _period = 'allTime';
  String? _currency;
  DateTimeRange? _range;

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

  List<Sale> _filter(List<Sale> sales, String currency) {
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
        : DateTime(now.year, now.month, now.day + 1);
    return sales
        .where(
          (sale) =>
              !sale.voided &&
              sale.settings.currency == currency &&
              (start == null || !sale.createdAt.isBefore(start)) &&
              sale.createdAt.isBefore(end),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final currencies = {
      store.settings.currency,
      ...store.sales.map((sale) => sale.settings.currency),
    }.toList()..sort();
    final currency = currencies.contains(_currency)
        ? _currency!
        : store.settings.currency;
    final sales = _filter(store.sales, currency);
    final revenue = sales.fold(0, (sum, s) => sum + s.subtotal - s.discount);
    final profit = sales.fold(
      0,
      (sum, s) => sum + s.subtotal - s.discount - s.cost,
    );
    final itemCount = sales.fold(
      0,
      (sum, sale) =>
          sum + sale.lines.fold(0, (count, line) => count + line.quantity),
    );
    final byStaff = <String, List<Sale>>{};
    for (final sale in sales) {
      byStaff.putIfAbsent(sale.cashierId, () => []).add(sale);
    }
    final staff = byStaff.values.toList()
      ..sort(
        (a, b) => b
            .fold(0, (sum, sale) => sum + sale.subtotal - sale.discount)
            .compareTo(
              a.fold(0, (sum, sale) => sum + sale.subtotal - sale.discount),
            ),
      );
    final low = store.products.where((p) => p.stock <= p.lowStock).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        PageHeading(
          title: 'overview',
          subtitle: 'reportSubtitle',
          action: currencies.length == 1
              ? StatusPill(currency)
              : SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(currency),
                    initialValue: currency,
                    decoration: InputDecoration(
                      labelText: context.tr('selectReportCurrency'),
                    ),
                    items: currencies
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _currency = value),
                  ),
                ),
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
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 540
                ? 1
                : constraints.maxWidth < 1000
                ? 2
                : 4;
            final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'revenue',
                    value: money(revenue, currency),
                    icon: Icons.payments_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'profit',
                    value: money(profit, currency),
                    icon: Icons.trending_up,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'transactions',
                    value: '${sales.length}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'itemsSold',
                    value: '$itemCount',
                    icon: Icons.shopping_bag_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('profitExplanation'),
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 24),
        _SevenDayTrend(sales: store.sales, currency: currency),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('staffPerformance'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (staff.isEmpty)
                  const EmptyState(icon: Icons.people_outline)
                else
                  for (final staffSales in staff)
                    _StaffSales(sales: staffSales, currency: currency),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('recentSales'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.navigate('sales'),
                      child: Text(context.tr('viewAll')),
                    ),
                  ],
                ),
                if (sales.isEmpty)
                  const EmptyState(icon: Icons.receipt_long_outlined)
                else
                  for (final sale in sales.take(5))
                    _SaleReceiptLink(sale: sale),
              ],
            ),
          ),
        ),
        if (store.canManageCatalog) ...[
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('stockWatch'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      StatusPill('${low.length}', color: amber),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (low.isEmpty)
                    const EmptyState(
                      title: 'healthyStock',
                      icon: Icons.check_circle_outline,
                    )
                  else
                    for (final product in low.take(4))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CatalogProductArt(product: product, size: 32),
                        title: Text(product.localizedName(store.language)),
                        subtitle: Text(
                          '${product.stock} ${context.tr('inStock')}',
                          style: const TextStyle(fontSize: 11, color: amber),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => widget.navigate('inventory'),
                      ),
                  TextButton(
                    onPressed: () => widget.navigate('inventory'),
                    child: Text(context.tr('viewAll')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SevenDayTrend extends StatelessWidget {
  const _SevenDayTrend({required this.sales, required this.currency});
  final List<Sale> sales;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final amounts = days
        .map(
          (day) => sales
              .where(
                (s) =>
                    !s.voided &&
                    s.settings.currency == currency &&
                    s.createdAt.year == day.year &&
                    s.createdAt.month == day.month &&
                    s.createdAt.day == day.day,
              )
              .fold(0, (sum, s) => sum + s.subtotal - s.discount),
        )
        .toList();
    final maximum = amounts.fold(1, (highest, n) => n > highest ? n : highest);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('salesTrend'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${context.tr('week')} · ${money(amounts.fold(0, (sum, n) => sum + n), currency)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 185,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FittedBox(
                              child: Text(
                                NumberFormat.compact().format(amounts[i] / 100),
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Tooltip(
                              message: money(amounts[i], currency),
                              child: Container(
                                height: 5 + 120 * amounts[i] / maximum,
                                decoration: BoxDecoration(
                                  color: i == 6 ? forest : sage,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FittedBox(
                              child: Text(
                                DateFormat(
                                  'EEE',
                                  context.store.language == 'en' ? 'en' : 'ar',
                                ).format(days[i]),
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffSales extends StatelessWidget {
  const _StaffSales({required this.sales, required this.currency});
  final List<Sale> sales;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final revenue = sales.fold(
      0,
      (sum, sale) => sum + sale.subtotal - sale.discount,
    );
    final profit = sales.fold(
      0,
      (sum, sale) => sum + sale.subtotal - sale.discount - sale.cost,
    );
    final itemCounts = <String, int>{};
    final itemNames = <String, String>{};
    for (final sale in sales) {
      for (final line in sale.lines) {
        itemCounts.update(
          line.productId,
          (value) => value + line.quantity,
          ifAbsent: () => line.quantity,
        );
        itemNames.putIfAbsent(line.productId, () => line.name);
      }
    }
    final itemCount = itemCounts.values.fold(0, (sum, value) => sum + value);
    final products = itemCounts.keys.toList()
      ..sort((a, b) => itemCounts[b]!.compareTo(itemCounts[a]!));
    return ExpansionTile(
      key: ValueKey('${sales.first.cashierId}-$currency'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 20),
      title: Text(
        sales.first.cashierName,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Wrap(
          spacing: 18,
          runSpacing: 5,
          children: [
            Text('${context.tr('transactions')}: ${sales.length}'),
            Text('${context.tr('itemsSold')}: $itemCount'),
            Text('${context.tr('revenue')}: ${money(revenue, currency)}'),
            Text('${context.tr('profit')}: ${money(profit, currency)}'),
          ],
        ),
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            context.tr('soldItems'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        for (final productId in products)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(child: Text(itemNames[productId]!)),
                const SizedBox(width: 16),
                Text('${itemCounts[productId]} ×'),
              ],
            ),
          ),
        const Divider(height: 28),
        for (final sale in sales) _SaleReceiptLink(sale: sale),
      ],
    );
  }
}

class _SaleReceiptLink extends StatelessWidget {
  const _SaleReceiptLink({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.receipt_long_outlined, color: forest),
    title: Text(
      sale.number,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      '${sale.cashierName} · ${dateLabel(sale.createdAt)}\n${money(sale.total, sale.settings.currency)}',
      style: const TextStyle(fontSize: 11, height: 1.6),
    ),
    trailing: const Icon(Icons.chevron_right, size: 18, color: muted),
    onTap: () => showReceipt(context, sale),
  );
}

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final entries = context.store.audit;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const PageHeading(title: 'audit', subtitle: 'auditSubtitle'),
        Card(
          child: Column(
            children: entries
                .map(
                  (e) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: sage,
                      child: Icon(Icons.history, color: forest, size: 20),
                    ),
                    title: Text(
                      context.tr(e.action),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${e.detail}\n${e.actor} · ${dateLabel(e.time)}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    isThreeLine: true,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
