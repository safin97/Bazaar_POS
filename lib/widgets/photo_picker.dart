import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/pos_store.dart';
import 'common.dart';

const productIconChoices = [
  '🥬',
  '🍎',
  '🍌',
  '🍅',
  '🥛',
  '🥚',
  '🥐',
  '🍞',
  '🥩',
  '🍗',
  '🍚',
  '🫒',
  '🍊',
  '💧',
  '🧃',
  '🧴',
  '🛒',
];

/// Stores a small, self-contained image so products work without a connection.
Future<String?> pickItemPhoto({int maxDimension = 512}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    withData: true,
  );
  if (result == null) return null;
  final file = result.files.single;
  if (file.size > 20 * 1024 * 1024) {
    throw const PosException('photoTooLarge');
  }
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw const PosException('invalidPhoto');
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    var scale = math.min(
      1.0,
      maxDimension / math.max(descriptor.width, descriptor.height),
    );
    while (true) {
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw const PosException('invalidPhoto');
      final encoded = base64Encode(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
      if (encoded.length <= 2 * 1024 * 1024) return encoded;
      if (math.max(image.width, image.height) <= 512) {
        throw const PosException('photoTooLarge');
      }
      image.dispose();
      image = null;
      codec.dispose();
      codec = null;
      scale *= 0.75;
    }
  } on PosException {
    rethrow;
  } catch (_) {
    throw const PosException('invalidPhoto');
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

class PhotoPicker extends StatefulWidget {
  const PhotoPicker({
    super.key,
    required this.photo,
    required this.emoji,
    required this.onChanged,
    this.onBusyChanged,
  });
  final String? photo;
  final String emoji;
  final ValueChanged<String?> onChanged;
  final ValueChanged<bool>? onBusyChanged;

  @override
  State<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends State<PhotoPicker> {
  bool _busy = false;

  Future<void> _pick() async {
    setState(() => _busy = true);
    widget.onBusyChanged?.call(true);
    try {
      final photo = await pickItemPhoto();
      if (mounted && photo != null) widget.onChanged(photo);
    } catch (error) {
      if (mounted) notifyError(context, error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr('photo'),
        style: const TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ProductArt(
              emoji: widget.emoji,
              photo: widget.photo,
              size: 76,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: _busy
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(
              context.tr(widget.photo == null ? 'uploadPhoto' : 'changePhoto'),
            ),
          ),
          if (widget.photo != null)
            IconButton(
              tooltip: context.tr('removePhoto'),
              onPressed: _busy ? null : () => widget.onChanged(null),
              icon: const Icon(Icons.delete_outline, color: danger),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        context.tr('photoHint'),
        style: const TextStyle(color: muted, fontSize: 11),
      ),
    ],
  );
}

class ProductIconPicker extends StatelessWidget {
  const ProductIconPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'productIcon',
  });
  final String value, label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr(label),
        style: const TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: productIconChoices
            .map(
              (emoji) => ChoiceChip(
                label: ProductArt(emoji: emoji, size: 24),
                tooltip: emoji,
                selected: value == emoji,
                showCheckmark: false,
                onSelected: (_) => onChanged(emoji),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 8),
      Text(
        context.tr('iconHint'),
        style: const TextStyle(color: muted, fontSize: 11),
      ),
    ],
  );
}
