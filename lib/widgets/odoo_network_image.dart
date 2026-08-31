import 'dart:convert';
import 'dart:typed_data';

import 'package:pi_task_watch/exports.dart';

/// Cache for image bytes to avoid repeated network requests
final Map<String, List<int>?> _imageCache = {};

class OdooNetworkImage extends StatefulWidget {
  final String? model;
  final int? id;
  final String field;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? base64Data;
  final String? directImageUrl;

  const OdooNetworkImage({
    super.key,
    this.model,
    this.id,
    this.field = 'image_1920',
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.base64Data,
    this.directImageUrl,
  });

  static void clearCache() => _imageCache.clear();
  static void evict(String model, int id, [String field = 'image_1920']) =>
      _imageCache.remove('${model}_${id}_$field');

  @override
  State<OdooNetworkImage> createState() => _OdooNetworkImageState();
}

class _OdooNetworkImageState extends State<OdooNetworkImage> {
  List<int>? _imageBytes;
  bool _loading = true;
  bool _hasError = false;

  String get _cacheKey => '${widget.model}_${widget.id}_${widget.field}';

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(OdooNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model ||
        oldWidget.id != widget.id ||
        oldWidget.field != widget.field) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    // Only for Odoo model images (not base64 or direct URL)
    if (widget.base64Data != null || widget.directImageUrl != null) {
      setState(() { _loading = false; });
      return;
    }

    if (widget.model == null || widget.id == null) {
      setState(() { _loading = false; _hasError = true; });
      return;
    }

    // Check cache first (only use valid non-empty cached bytes)
    final key = _cacheKey;
    if (_imageCache.containsKey(key) &&
        _imageCache[key] != null &&
        _imageCache[key]!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _imageBytes = _imageCache[key];
          _loading = false;
          _hasError = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }

    // Fetch via authenticated Odoo RPC
    try {
      final bytes = await OdooRpcApiManager.fetchImageBytes(
        model: widget.model!,
        id: widget.id!,
        field: widget.field,
      );
      if (bytes != null && bytes.isNotEmpty) {
        _imageCache[key] = bytes;
      }
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _loading = false;
          _hasError = bytes == null || bytes.isEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  bool _isValidImageBytes(List<int> bytes) {
    if (bytes.length < 4) return false;
    // JPEG (FF D8)
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    // PNG (89 50 4E 47)
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) return true;
    // GIF (47 49 46)
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WEBP (RIFF....WEBP)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    // BMP (42 4D)
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // 1. base64 data
    if (widget.base64Data != null && widget.base64Data!.isNotEmpty) {
      try {
        final decoded = base64Decode(widget.base64Data!);
        if (!_isValidImageBytes(decoded)) return _buildErrorWidget();
        return Image.memory(
          decoded,
          width: widget.width,
          height: widget.height,
          fit: widget.fit ?? BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      } catch (e) {
        return _buildErrorWidget();
      }
    }

    // 2. Direct URL (non-Odoo, e.g. public CDN)
    if (widget.directImageUrl != null && widget.directImageUrl!.isNotEmpty) {
      return Image.network(
        widget.directImageUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit ?? BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(context);
        },
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    // 3. Odoo model image via authenticated Dio (session cookie in headers)
    if (_loading) return _buildPlaceholder(context);
    if (_hasError || _imageBytes == null || _imageBytes!.isEmpty) return _buildErrorWidget();
    if (!_isValidImageBytes(_imageBytes!)) return _buildErrorWidget();

    return Image.memory(
      Uint8List.fromList(_imageBytes!),
      width: widget.width,
      height: widget.height,
      fit: widget.fit ?? BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return widget.placeholder ??
        Center(
          child: SizedBox(
            width: (widget.width ?? 24) * 0.6,
            height: (widget.height ?? 24) * 0.6,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).primaryColor,
            ),
          ),
        );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ??
        widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.person_rounded, color: Colors.grey[400]),
        );
  }
}
