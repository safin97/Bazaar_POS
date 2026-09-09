import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/branding.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/pos_store.dart';

void notifyError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        context.tr(error is PosException ? error.key : 'somethingWrong'),
      ),
      backgroundColor: danger,
    ),
  );
}

void notifySaved(BuildContext context, [String key = 'saved']) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr(key))));

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'delete',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr(title)),
        content: Text(ctx.tr(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr(action)),
          ),
        ],
      ),
    ) ??
    false;

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42, this.settings});
  final double size;
  final StoreSettings? settings;
  @override
  Widget build(BuildContext context) {
    final bytes = (settings ?? context.store.settings).logoBytes;
    return SizedBox(
      width: size,
      height: size,
      child: bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size * .28),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    Image.asset(defaultLogoAsset, fit: BoxFit.contain),
              ),
            )
          : Image.asset(defaultLogoAsset, fit: BoxFit.contain),
    );
  }
}

class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: context.tr('language'),
    initialValue: context.store.language,
    onSelected: (code) {
      try {
        context.store.setLanguage(code);
      } catch (e) {
        notifyError(context, e);
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'en', child: Text('English')),
      PopupMenuItem(value: 'ku', child: Text('کوردی بادینی')),
      PopupMenuItem(value: 'ar', child: Text('العربية')),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language_rounded, size: 18, color: muted),
          const SizedBox(width: 8),
          Text(switch (context.store.language) {
            'ar' => 'العربية',
            'ku' => 'کوردی بادینی',
            _ => 'English',
          }, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          const Icon(Icons.expand_more, size: 16),
        ],
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(title),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(subtitle),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: constraints.maxWidth < 540
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text,
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  if (action != null) ...[const SizedBox(width: 16), action!],
                ],
              ),
      );
    },
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color = forest});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = forest,
    this.note,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  final String? note;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              const Icon(Icons.north_east, size: 15, color: muted),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -.7,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.tr(label),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note!, style: const TextStyle(color: muted, fontSize: 10)),
          ],
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.title = 'noResults',
    this.subtitle,
    this.icon = Icons.inventory_2_outlined,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: sage,
            ),
            child: Icon(icon, size: 32, color: forest),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr(title),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              context.tr(subtitle!),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ],
      ),
    ),
  );
}

class Field extends StatelessWidget {
  const Field(
    this.controller,
    this.label, {
    super.key,
    this.required = false,
    this.moneyValue = false,
    this.integer = false,
    this.obscure = false,
    this.hint,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final bool required, moneyValue, integer, obscure;
  final String? hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      obscureText: obscure,
      maxLines: maxLines,
      onChanged: onChanged,
      keyboardType: moneyValue
          ? const TextInputType.numberWithOptions(decimal: true)
          : integer
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: context.tr(label),
        helperText: hint == null ? null : context.tr(hint!),
        helperMaxLines: 2,
      ),
      validator:
          validator ??
          (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return context.tr('required');
            }
            if (moneyValue && parseMoney(value ?? '') == null) {
              return context.tr('invalidNumber');
            }
            if (integer &&
                (int.tryParse(value ?? '') == null || int.parse(value!) < 0)) {
              return context.tr('invalidNumber');
            }
            return null;
          },
    ),
  );
}

class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    this.busy = false,
  });
  final String title;
  final Widget child;
  final VoidCallback onSave;
  final bool busy;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 580,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(title),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('close'),
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: Text(context.tr('cancel')),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: busy ? null : onSave,
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('save')),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Bundled illustrations avoid network font fallback and platform emoji differences.
/// Products can inherit category uploads or display their own artwork.
class CatalogProductArt extends StatelessWidget {
  const CatalogProductArt({
    super.key,
    required this.product,
    required this.size,
  });
  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final category = context.store.categories
        .where(
          (category) =>
              category.id == product.category &&
              category.marketId == product.marketId,
        )
        .firstOrNull;
    return ProductArt(
      emoji: product.emoji,
      photo: product.useCategoryIcon
          ? category?.photo ?? product.photo
          : product.photo,
      size: size,
    );
  }
}

class ProductArt extends StatelessWidget {
  const ProductArt({
    super.key,
    required this.emoji,
    this.photo,
    this.size = 32,
  });
  final String emoji;
  final String? photo;
  final double size;
  @override
  Widget build(BuildContext context) {
    final code = emoji.runes
        .where((c) => c != 0xfe0f)
        .map((c) => c.toRadixString(16))
        .join('-');
    final fallback = Image.asset(
      'assets/products/$code.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.shopping_basket_outlined, size: size, color: forest),
    );
    if (photo != null && photo!.isNotEmpty) {
      try {
        return ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * .12),
            child: Image.memory(
              base64Decode(photo!),
              width: size,
              height: size,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => fallback,
            ),
          ),
        );
      } on FormatException {
        // A damaged optional photo must not prevent a product being sold.
      }
    }
    return ExcludeSemantics(child: fallback);
  }
}
