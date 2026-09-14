import 'package:flutter/material.dart';

import '../core/branding.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';
import 'photo_picker.dart';

class MarketBrandingEditor extends StatefulWidget {
  const MarketBrandingEditor({
    super.key,
    required this.branding,
    required this.onChanged,
    required this.onBusyChanged,
    this.enabled = true,
  });

  final MarketBranding branding;
  final ValueChanged<MarketBranding> onChanged;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled;

  @override
  State<MarketBrandingEditor> createState() => _MarketBrandingEditorState();
}

class _MarketBrandingEditorState extends State<MarketBrandingEditor> {
  bool _picking = false;

  Future<void> _pick({required bool background}) async {
    if (_picking || !widget.enabled) return;
    setState(() => _picking = true);
    widget.onBusyChanged(true);
    try {
      final photo = await pickItemPhoto(maxDimension: background ? 1600 : 512);
      if (mounted && photo != null) {
        widget.onChanged(
          MarketBranding(
            logo: background ? widget.branding.logo : photo,
            background: background ? photo : widget.branding.background,
          ),
        );
      }
    } catch (error) {
      if (mounted) notifyError(context, error);
    } finally {
      if (mounted) {
        setState(() => _picking = false);
        widget.onBusyChanged(false);
      }
    }
  }

  Widget _imageField({required bool background}) {
    final bytes = background
        ? widget.branding.backgroundBytes
        : widget.branding.logoBytes;
    final asset = background ? welcomeBackgroundAsset : defaultLogoAsset;
    final fit = background ? BoxFit.cover : BoxFit.contain;
    final enabled = widget.enabled && !_picking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(background ? 'background' : 'logo'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                key: ValueKey(
                  background
                      ? 'admin-background-preview'
                      : 'admin-logo-preview',
                ),
                width: background ? 160 : 76,
                height: background ? 90 : 76,
                child: bytes == null
                    ? Image.asset(asset, fit: fit)
                    : Image.memory(
                        bytes,
                        fit: fit,
                        errorBuilder: (_, _, _) => Image.asset(asset, fit: fit),
                      ),
              ),
            ),
            OutlinedButton.icon(
              key: ValueKey(
                background ? 'admin-upload-background' : 'admin-upload-logo',
              ),
              onPressed: enabled ? () => _pick(background: background) : null,
              icon: const Icon(Icons.upload_outlined, size: 17),
              label: Text(
                context.tr(background ? 'uploadBackground' : 'uploadLogo'),
              ),
            ),
            if (bytes != null)
              IconButton(
                key: ValueKey(
                  background ? 'admin-remove-background' : 'admin-remove-logo',
                ),
                tooltip: context.tr(
                  background ? 'removeBackground' : 'removeLogo',
                ),
                onPressed: !enabled
                    ? null
                    : () => widget.onChanged(
                        MarketBranding(
                          logo: background ? widget.branding.logo : null,
                          background: background
                              ? null
                              : widget.branding.background,
                        ),
                      ),
                icon: const Icon(Icons.delete_outline, color: danger),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr('adminBranding'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 6),
      Text(
        context.tr('adminBrandingHint'),
        style: const TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 16),
      _imageField(background: false),
      const SizedBox(height: 16),
      _imageField(background: true),
      const SizedBox(height: 8),
      Text(
        context.tr('photoHint'),
        style: const TextStyle(color: muted, fontSize: 10),
      ),
    ],
  );
}
