import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/pos_store.dart';
import '../widgets/common.dart';
import '../widgets/receipt.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _search = TextEditingController();
  final Map<String, int> _cart = {};
  String _category = 'all', _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add(Product p, [int delta = 1]) {
    final quantity = (_cart[p.id] ?? 0) + delta;
    if (quantity > p.stock) {
      notifyError(context, const PosException('insufficientStock'));
      return;
    }
    setState(() {
      if (quantity <= 0) {
        _cart.remove(p.id);
      } else {
        _cart[p.id] = quantity;
      }
    });
  }

  int _subtotal(PosStore store) => _cart.entries.fold(
    0,
    (s, e) =>
        s +
        (store.products.where((p) => p.id == e.key).firstOrNull?.price ?? 0) *
            e.value,
  );
  Future<void> _pay() async {
    final sale = await showDialog<Sale>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(quantities: Map.of(_cart)),
    );
    if (sale != null && mounted) {
      setState(_cart.clear);
      await showReceipt(context, sale);
    }
  }

  Future<void> _mobileCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, refresh) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .88,
          child: _cartPanel(
            onChange: () => refresh(() {}),
            onPay: () {
              Navigator.pop(sheetContext);
              _pay();
            },
          ),
        ),
      ),
    );
  }

  Widget _cartPanel({VoidCallback? onChange, VoidCallback? onPay}) {
    final store = context.store;
    final subtotal = _subtotal(store);
    final tax = (subtotal * store.settings.taxBasisPoints + 5000) ~/ 10000;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: BorderDirectional(start: BorderSide(color: line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('currentOrder'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_cart.values.fold(0, (s, q) => s + q)} ${context.tr('items')}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _cart.isEmpty
                      ? null
                      : () {
                          setState(_cart.clear);
                          onChange?.call();
                        },
                  child: Text(
                    context.tr('clear'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: canvas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('walkIn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _cart.isEmpty
                ? const EmptyState(
                    title: 'emptyCartTitle',
                    subtitle: 'emptyCartHint',
                    icon: Icons.shopping_bag_outlined,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _cart.length,
                    separatorBuilder: (_, _) => const Divider(height: 28),
                    itemBuilder: (context, index) {
                      final entry = _cart.entries.elementAt(index);
                      final p = store.products
                          .where((p) => p.id == entry.key)
                          .firstOrNull;
                      if (p == null) {
                        return ListTile(
                          title: Text(context.tr('outOfStock')),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() => _cart.remove(entry.key));
                              onChange?.call();
                            },
                          ),
                        );
                      }
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: sage,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: CatalogProductArt(product: p, size: 26),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.localizedName(store.language),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      p.unit,
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: context.tr('removeItem'),
                                visualDensity: VisualDensity.compact,
                                iconSize: 16,
                                onPressed: () {
                                  setState(() => _cart.remove(p.id));
                                  onChange?.call();
                                },
                                icon: const Icon(Icons.close, color: muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: line),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      tooltip: context.tr('decreaseQuantity'),
                                      constraints: const BoxConstraints(
                                        minWidth: 34,
                                        minHeight: 34,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      iconSize: 15,
                                      onPressed: () {
                                        _add(p, -1);
                                        onChange?.call();
                                      },
                                      icon: const Icon(Icons.remove),
                                    ),
                                    SizedBox(
                                      width: 25,
                                      child: Text(
                                        '${entry.value}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: context.tr('increaseQuantity'),
                                      constraints: const BoxConstraints(
                                        minWidth: 34,
                                        minHeight: 34,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      iconSize: 15,
                                      onPressed: () {
                                        _add(p);
                                        onChange?.call();
                                      },
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                money(
                                  p.price * entry.value,
                                  store.settings.currency,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: line)),
            ),
            child: Column(
              children: [
                _totalRow('subtotal', subtotal),
                const SizedBox(height: 10),
                _totalRow('tax', tax),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 9),
                  child: Divider(),
                ),
                _totalRow('total', subtotal + tax, bold: true),
                if (secondaryMoney(subtotal + tax, store.settings) case final reference?) ...[
                  const SizedBox(height: 6),
                  Text(
                    '$reference · ${context.tr('displayOnly')}',
                    style: const TextStyle(color: muted, fontSize: 11),
                    textAlign: TextAlign.end,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _cart.isEmpty ? null : (onPay ?? _pay),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.tr('checkout')),
                        Text(money(subtotal + tax, store.settings.currency)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 12,
                      color: muted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        context.tr('localOnly'),
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, int amount, {bool bold = false}) => Row(
    children: [
      Expanded(
        child: Text(
          context.tr(label),
          style: TextStyle(
            fontSize: bold ? 17 : 12,
            color: bold ? ink : muted,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
      Text(
        money(amount, context.store.settings.currency),
        style: TextStyle(
          fontSize: bold ? 20 : 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    if (_category != 'all' && !store.categories.any((c) => c.id == _category)) {
      _category = 'all';
    }
    final products = store.products
        .where(
          (p) =>
              (_category == 'all' || p.category == _category) &&
              '${p.name} ${p.arabicName} ${p.kurdishName} ${p.barcode}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(26, 28, 26, 0),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const PageHeading(
                                  title: 'newSale',
                                  subtitle: 'registerSubtitle',
                                ),
                                TextField(
                                  controller: _search,
                                  onChanged: (v) => setState(() => _query = v),
                                  onSubmitted: (v) {
                                    final found = store.products
                                        .where((p) => p.barcode == v.trim())
                                        .firstOrNull;
                                    if (found != null) {
                                      _add(found);
                                      _search.clear();
                                      setState(() => _query = '');
                                    } else {
                                      notifyError(
                                        context,
                                        const PosException('noResults'),
                                      );
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: context.tr('searchProducts'),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 21,
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.qr_code_scanner_rounded,
                                      size: 20,
                                      color: muted,
                                    ),
                                    fillColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                SizedBox(
                                  height: 90,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: store.categories.length + 1,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final category = index == 0
                                          ? null
                                          : store.categories[index - 1];
                                      final cat = category?.id ?? 'all';
                                      final selected = cat == _category;
                                      return Semantics(
                                        button: true,
                                        selected: selected,
                                        child: Material(
                                          color: selected
                                              ? forest
                                              : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              13,
                                            ),
                                            side: BorderSide(
                                              color: selected ? forest : line,
                                            ),
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              13,
                                            ),
                                            onTap: () =>
                                                setState(() => _category = cat),
                                            child: SizedBox(
                                              width: 95,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  if (index == 0)
                                                    Icon(
                                                      Icons.grid_view_rounded,
                                                      color: selected
                                                          ? Colors.white
                                                          : forest,
                                                      size: 24,
                                                    )
                                                  else
                                                    ProductArt(
                                                      emoji: category!.emoji,
                                                      photo: category.photo,
                                                      size: 24,
                                                    ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    category?.localizedName(
                                                          store.language,
                                                        ) ??
                                                        context.tr('all'),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: selected
                                                          ? Colors.white
                                                          : ink,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 27),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        store.categories
                                                .where((c) => c.id == _category)
                                                .firstOrNull
                                                ?.localizedName(
                                                  store.language,
                                                ) ??
                                            context.tr('all'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    StatusPill('${products.length}'),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.grid_view_outlined,
                                      size: 17,
                                      color: muted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 17),
                              ],
                            ),
                          ),
                        ),
                        if (products.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(subtitle: 'noProductsHint'),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
                            sliver: SliverLayoutBuilder(
                              builder: (context, c) {
                                final count = (c.crossAxisExtent / 175)
                                    .floor()
                                    .clamp(2, 6);
                                return SliverGrid(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) => _ProductCard(
                                      product: products[i],
                                      quantity: _cart[products[i].id] ?? 0,
                                      onTap: () => _add(products[i]),
                                    ),
                                    childCount: products.length,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: count,
                                        mainAxisExtent:
                                            store.settings.secondaryCurrency == null
                                            ? 218
                                            : 238,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 14,
                                      ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!wide)
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _mobileCart,
                            icon: Badge(
                              label: Text(
                                '${_cart.values.fold(0, (s, q) => s + q)}',
                              ),
                              child: const Icon(Icons.shopping_bag_outlined),
                            ),
                            label: Text(
                              '${context.tr('reviewOrder')} · ${money(_subtotal(store), store.settings.currency)}',
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (wide) SizedBox(width: 342, child: _cartPanel()),
          ],
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onTap,
  });
  final Product product;
  final int quantity;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = product;
    final bg = switch (p.category) {
      'produce' => const Color(0xFFF0F4E8),
      'dairy' => const Color(0xFFEDF3F6),
      'bakery' => const Color(0xFFFAF0E2),
      'meat' => const Color(0xFFF6EBE7),
      'drinks' => const Color(0xFFFFF2E0),
      _ => const Color(0xFFF2F1E9),
    };
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: quantity > 0 ? forest : line,
          width: quantity > 0 ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: p.stock == 0 ? null : onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CatalogProductArt(product: p, size: 56),
                      if (quantity > 0)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: forest,
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 11),
              Text(
                p.localizedName(context.store.language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(p.unit, style: const TextStyle(fontSize: 10, color: muted)),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        money(p.price, context.store.settings.currency),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: forest,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: sage,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 17,
                      color: forest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              if (secondaryMoney(p.price, context.store.settings) case final reference?) ...[
                Text(
                  reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
                const SizedBox(height: 5),
              ],
              Text(
                p.stock == 0
                    ? context.tr('outOfStock')
                    : '${p.stock} ${context.tr('inStock')}',
                style: TextStyle(
                  fontSize: 9,
                  color: p.stock <= p.lowStock ? amber : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.quantities});
  final Map<String, int> quantities;
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _discount = TextEditingController(text: '0');
  final _received = TextEditingController();
  String _method = 'cash';
  bool _busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_received.text.isEmpty) {
      _received.text = (_total / 100).toStringAsFixed(2);
    }
  }

  int get _subtotal => widget.quantities.entries.fold(
    0,
    (s, e) =>
        s +
        (context.store.products
                    .where((p) => p.id == e.key)
                    .firstOrNull
                    ?.price ??
                0) *
            e.value,
  );
  int get _discountValue => parseMoney(_discount.text) ?? 0;
  int get _tax =>
      ((_subtotal - _discountValue) * context.store.settings.taxBasisPoints +
          5000) ~/
      10000;
  int get _total => _subtotal - _discountValue + _tax;
  @override
  void dispose() {
    _discount.dispose();
    _received.dispose();
    super.dispose();
  }

  void _complete() {
    if (_busy) return;
    if (parseMoney(_discount.text) == null) {
      notifyError(context, const PosException('invalidDiscount'));
      return;
    }
    setState(() => _busy = true);
    try {
      final sale = context.store.checkout(
        widget.quantities,
        discount: _discountValue,
        paymentMethod: _method,
        tendered: _method == 'card' ? _total : parseMoney(_received.text) ?? -1,
      );
      Navigator.pop(context, sale);
    } catch (e) {
      notifyError(context, e);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('payment'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              money(_total, context.store.settings.currency),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: forest,
              ),
            ),
            if (secondaryMoney(_total, context.store.settings) case final reference?) ...[
              const SizedBox(height: 6),
              Text(
                '$reference · ${context.tr('displayOnly')}',
                style: const TextStyle(fontSize: 16, color: muted),
              ),
              const SizedBox(height: 6),
              Text(
                '${context.tr('paymentsInMainCurrency')}: ${context.store.settings.currency}',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${context.tr('tax')}: ${money(_tax, context.store.settings.currency)}',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['cash', 'card']
                  .map(
                    (m) => ChoiceChip(
                      label: Text(context.tr(m)),
                      selected: _method == m,
                      onSelected: (_) => setState(() => _method = m),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 22),
            if (context.store.canDiscount)
              Field(
                _discount,
                'discount',
                moneyValue: true,
                onChanged: (_) => setState(() {}),
              ),
            if (_method == 'cash') ...[
              Field(
                _received,
                'amountReceived',
                moneyValue: true,
                onChanged: (_) => setState(() {}),
              ),
              Text(
                '${context.tr('change')}: ${money(((parseMoney(_received.text) ?? 0) - _total).clamp(0, 100000000000000), context.store.settings.currency)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ] else
              Text(
                context.tr('cardNote'),
                style: const TextStyle(color: amber, fontSize: 12),
              ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _busy ? null : _complete,
              child: Text(context.tr('completeSale')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: Text(context.tr('cancel')),
            ),
          ],
        ),
      ),
    ),
  );
}
