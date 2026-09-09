import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/pos_store.dart';
import '../widgets/common.dart';
import '../widgets/photo_picker.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _query = '';

  void _edit([ProductCategory? category]) => showDialog<String>(
    context: context,
    builder: (_) => CategoryEditor(category: category),
  );

  Future<void> _delete(ProductCategory category) async {
    if (!await confirmAction(
      context,
      title: 'confirmDelete',
      message: 'deleteHint',
    )) {
      return;
    }
    if (!mounted) return;
    try {
      context.store.deleteCategory(category.id);
      notifySaved(context);
    } catch (error) {
      notifyError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final categories = store.categories.where(
      (category) =>
          '${category.name} ${category.arabicName} ${category.kurdishName}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
    );
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        PageHeading(
          title: 'categories',
          subtitle: 'categoriesSubtitle',
          action: FilledButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.add, size: 19),
            label: Text(context.tr('addCategory')),
          ),
        ),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: context.tr('search'),
            prefixIcon: const Icon(Icons.search, size: 20),
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 22),
        if (categories.isEmpty)
          const EmptyState(subtitle: 'noCategoriesHint')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: categories.map((category) {
                  final count = store.products
                      .where((p) => p.category == category.id)
                      .length;
                  return SizedBox(
                    width: width,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _edit(category),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: sage,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ProductArt(
                                  emoji: category.emoji,
                                  photo: category.photo,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.localizedName(store.language),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '$count ${context.tr('products')}',
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: context.tr('edit'),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _edit(category);
                                  } else {
                                    _delete(category);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(context.tr('edit')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      context.tr('delete'),
                                      style: const TextStyle(color: danger),
                                    ),
                                  ),
                                ],
                                icon: const Icon(Icons.more_vert, color: muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

class CategoryEditor extends StatefulWidget {
  const CategoryEditor({super.key, this.category});
  final ProductCategory? category;

  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _arabic, _kurdish, _customIcon;
  late String _emoji;
  String? _photo;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _name = TextEditingController(text: category?.name ?? '');
    _arabic = TextEditingController(text: category?.arabicName ?? '');
    _kurdish = TextEditingController(text: category?.kurdishName ?? '');
    _emoji = category?.emoji ?? '🛒';
    _customIcon = TextEditingController(text: _emoji);
    _photo = category?.photo;
  }

  @override
  void dispose() {
    _name.dispose();
    _arabic.dispose();
    _kurdish.dispose();
    _customIcon.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate() || _photoBusy) return;
    try {
      final category = ProductCategory(
        id: widget.category?.id ?? PosStore.newId(),
        marketId: widget.category?.marketId ?? context.store.activeMarketId,
        name: _name.text.trim(),
        arabicName: _arabic.text.trim(),
        kurdishName: _kurdish.text.trim(),
        emoji: _emoji,
        photo: _photo,
      );
      context.store.saveCategory(category);
      Navigator.pop(context, category.id);
      notifySaved(context);
    } catch (error) {
      notifyError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
    title: widget.category == null ? 'addCategory' : 'editCategory',
    busy: _photoBusy,
    onSave: _save,
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(_name, 'categoryName', required: true),
          Field(_arabic, 'arabicName'),
          Field(_kurdish, 'kurdishName'),
          PhotoPicker(
            photo: _photo,
            emoji: _emoji,
            onChanged: (value) => setState(() => _photo = value),
            onBusyChanged: (value) => setState(() => _photoBusy = value),
          ),
          const SizedBox(height: 24),
          ProductIconPicker(
            label: 'categoryIcon',
            value: _emoji,
            onChanged: (value) => setState(() {
              _emoji = value;
              _customIcon.text = value;
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('custom-category-icon'),
            controller: _customIcon,
            maxLength: 1,
            decoration: InputDecoration(
              labelText: context.tr('customCategoryIcon'),
              helperText: context.tr('customCategoryIconHint'),
              helperMaxLines: 3,
            ),
            onChanged: (value) => setState(() {
              _emoji = value.trim().isEmpty ? '🛒' : value.trim();
            }),
          ),
        ],
      ),
    ),
  );
}
