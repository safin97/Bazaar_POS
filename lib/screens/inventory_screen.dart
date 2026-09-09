import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/pos_store.dart';
import '../widgets/common.dart';
import '../widgets/photo_picker.dart';
import 'categories_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _query = '';
  bool _lowOnly = false;
  void _edit([Product? p]) => showDialog<void>(
    context: context,
    builder: (_) => ProductEditor(product: p),
  );
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final categoryNames = {
      for (final category in store.categories)
        category.id: category.localizedName(store.language),
    };
    final products = store.products
        .where(
          (p) =>
              (!_lowOnly || p.stock <= p.lowStock) &&
              '${p.name} ${p.arabicName} ${p.kurdishName} ${p.barcode}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        PageHeading(
          title: 'inventory',
          subtitle: 'inventorySubtitle',
          action: store.canManageCatalog
              ? FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.add, size: 19),
                  label: Text(context.tr('addProduct')),
                )
              : null,
        ),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: c.maxWidth < 650 ? c.maxWidth : (c.maxWidth - 32) / 3,
                child: MetricCard(
                  label: 'products',
                  value: '${store.products.length}',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              if (store.canManageCatalog || store.canViewReports)
                SizedBox(
                  width: c.maxWidth < 650 ? c.maxWidth : (c.maxWidth - 32) / 3,
                  child: MetricCard(
                    label: 'stockValue',
                    value: money(
                      store.products.fold(0, (s, p) => s + p.cost * p.stock),
                      store.settings.currency,
                    ),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              SizedBox(
                width: c.maxWidth < 650 ? c.maxWidth : (c.maxWidth - 32) / 3,
                child: MetricCard(
                  label: 'needsAttention',
                  value:
                      '${store.products.where((p) => p.stock <= p.lowStock).length}',
                  icon: Icons.warning_amber_rounded,
                  color: amber,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  fillColor: Colors.white,
                ),
              ),
            ),
            FilterChip(
              label: Text(context.tr('lowStock')),
              selected: _lowOnly,
              onSelected: (v) => setState(() => _lowOnly = v),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (products.isEmpty)
          const EmptyState(subtitle: 'noProductsHint')
        else
          Card(
            child: LayoutBuilder(
              builder: (context, c) => c.maxWidth < 650
                  ? Column(
                      children: products
                          .map(
                            (p) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              leading: CatalogProductArt(product: p, size: 28),
                              title: Text(
                                p.localizedName(store.language),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${money(p.price, store.settings.currency)} · ${p.stock} ${context.tr('inStock')}',
                                style: const TextStyle(fontSize: 10),
                              ),
                              trailing: store.canManageCatalog
                                  ? _actions(p)
                                  : null,
                              onTap: store.canManageCatalog
                                  ? () => _edit(p)
                                  : null,
                            ),
                          )
                          .toList(),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: c.maxWidth),
                        child: DataTable(
                          headingRowColor: const WidgetStatePropertyAll(canvas),
                          dataRowMinHeight: 68,
                          dataRowMaxHeight: 68,
                          columns:
                              [
                                    'product',
                                    'category',
                                    'price',
                                    'stock',
                                    'status',
                                    if (store.canManageCatalog) 'edit',
                                  ]
                                  .map(
                                    (key) => DataColumn(
                                      label: Text(
                                        context.tr(key),
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          rows: products
                              .map(
                                (p) => DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CatalogProductArt(
                                            product: p,
                                            size: 28,
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.localizedName(store.language),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                p.barcode,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      onTap: store.canManageCatalog
                                          ? () => _edit(p)
                                          : null,
                                    ),
                                    DataCell(
                                      Text(
                                        categoryNames[p.category] ??
                                            context.tr(p.category),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        money(p.price, store.settings.currency),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${p.stock}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      StatusPill(
                                        context.tr(
                                          p.stock == 0
                                              ? 'outOfStock'
                                              : p.stock <= p.lowStock
                                              ? 'lowStock'
                                              : 'active',
                                        ),
                                        color: p.stock <= p.lowStock
                                            ? amber
                                            : forest,
                                      ),
                                    ),
                                    if (store.canManageCatalog)
                                      DataCell(_actions(p)),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _actions(Product p) => PopupMenuButton<String>(
    tooltip: context.tr('edit'),
    onSelected: (action) async {
      if (action == 'edit') {
        _edit(p);
        return;
      }
      if (await confirmAction(
            context,
            title: 'confirmDelete',
            message: 'deleteHint',
          ) &&
          mounted) {
        try {
          context.store.deleteProduct(p.id);
          notifySaved(context);
        } catch (e) {
          notifyError(context, e);
        }
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'edit', child: Text(context.tr('edit'))),
      PopupMenuItem(
        value: 'delete',
        child: Text(
          context.tr('delete'),
          style: const TextStyle(color: danger),
        ),
      ),
    ],
    icon: const Icon(Icons.more_horiz, color: muted),
  );
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, this.product});
  final Product? product;
  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  String? _category, _photo;
  late String _emoji;
  bool _photoBusy = false;
  bool _useCategoryIcon = true;
  bool _initializedCategory = false;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _c = {
      'icon': p?.emoji ?? '🛒',
      'name': p?.name ?? '',
      'ar': p?.arabicName ?? '',
      'ku': p?.kurdishName ?? '',
      'barcode': p?.barcode ?? '',
      'price': p == null ? '' : (p.price / 100).toStringAsFixed(2),
      'cost': p == null ? '0' : (p.cost / 100).toStringAsFixed(2),
      'stock': '${p?.stock ?? 0}',
      'unit': p?.unit ?? 'piece',
      'low': '${p?.lowStock ?? 10}',
    }.map((k, v) => MapEntry(k, TextEditingController(text: v)));
    _category = p?.category;
    _emoji = p?.emoji ?? '🛒';
    _photo = p?.photo;
    _useCategoryIcon = p?.useCategoryIcon ?? true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedCategory) return;
    final categories = context.store.categories;
    if (!categories.any((category) => category.id == _category)) {
      _category = categories.isEmpty ? null : categories.first.id;
    }
    _initializedCategory = true;
  }

  Future<void> _addCategory() async {
    final id = await showDialog<String>(
      context: context,
      builder: (_) => const CategoryEditor(),
    );
    if (mounted && id != null) setState(() => _category = id);
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate() || _photoBusy) return;
    try {
      context.store.saveProduct(
        Product(
          id: widget.product?.id ?? PosStore.newId(),
          marketId: widget.product?.marketId ?? context.store.activeMarketId,
          name: _c['name']!.text.trim(),
          arabicName: _c['ar']!.text.trim(),
          kurdishName: _c['ku']!.text.trim(),
          barcode: _c['barcode']!.text.trim(),
          category: _category!,
          emoji: _emoji,
          photo: _photo,
          useCategoryIcon: _useCategoryIcon,
          price: parseMoney(_c['price']!.text)!,
          cost: parseMoney(_c['cost']!.text)!,
          stock: int.parse(_c['stock']!.text),
          lowStock: int.parse(_c['low']!.text),
          unit: _c['unit']!.text.trim(),
        ),
      );
      Navigator.pop(context);
      notifySaved(context);
    } catch (e) {
      notifyError(context, e);
    }
  }

  ProductCategory? get _selectedCategory => context.store.categories
      .where((category) => category.id == _category)
      .firstOrNull;

  @override
  Widget build(BuildContext context) => FormDialog(
    title: widget.product == null ? 'addProduct' : 'editProduct',
    busy: _photoBusy,
    onSave: _save,
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(_c['name']!, 'productName', required: true),
          Field(_c['ar']!, 'arabicName'),
          Field(_c['ku']!, 'kurdishName'),
          Field(_c['barcode']!, 'barcode', required: true),
          DropdownButtonFormField<String>(
            key: ValueKey(_category),
            initialValue: _category,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('category')),
            hint: Text(context.tr('addCategoryFirst')),
            items: context.store.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Row(
                      children: [
                        ProductArt(
                          emoji: category.emoji,
                          photo: category.photo,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            category.localizedName(context.store.language),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            validator: (value) =>
                value == null ? context.tr('addCategoryFirst') : null,
            onChanged: (value) => setState(() => _category = value),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.tr('addCategory')),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            key: const ValueKey('use-category-icon'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('useCategoryIcon')),
            subtitle: Text(context.tr('useCategoryIconHint')),
            value: _useCategoryIcon,
            onChanged: _photoBusy
                ? null
                : (value) => setState(() => _useCategoryIcon = value),
          ),
          if (_useCategoryIcon && _selectedCategory?.photo != null) ...[
            ProductArt(
              emoji: _selectedCategory!.emoji,
              photo: _selectedCategory!.photo,
              size: 76,
            ),
            const SizedBox(height: 8),
            Text(context.tr('categoryIconShared')),
          ] else ...[
            PhotoPicker(
              photo: _photo,
              emoji: _emoji,
              onChanged: (value) => setState(() {
                _photo = value;
                _useCategoryIcon = false;
              }),
              onBusyChanged: (value) => setState(() => _photoBusy = value),
            ),
            const SizedBox(height: 24),
            ProductIconPicker(
              value: _emoji,
              onChanged: (value) => setState(() {
                _emoji = value;
                _c['icon']!.text = value;
                _useCategoryIcon = false;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('custom-product-icon'),
              controller: _c['icon'],
              maxLength: 1,
              decoration: InputDecoration(
                labelText: context.tr('customProductIcon'),
              ),
              onChanged: (value) => setState(() {
                _emoji = value.trim().isEmpty ? '🛒' : value.trim();
                _useCategoryIcon = false;
              }),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Field(_c['price']!, 'price', moneyValue: true)),
              const SizedBox(width: 16),
              Expanded(child: Field(_c['cost']!, 'cost', moneyValue: true)),
            ],
          ),
          Field(_c['stock']!, 'stock', integer: true),
          Field(_c['unit']!, 'unit', required: true),
          Field(_c['low']!, 'lowStockThreshold', integer: true),
        ],
      ),
    ),
  );
}
