import 'dart:convert';

import 'package:pi_task_watch/exports.dart';

class OdooNetworkImage extends StatelessWidget {
  final String? model;
  final int? id;
  final String field;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? base64Data; // Add support for direct base64 data
  final String? directImageUrl; // Add support for direct complete URL

  const OdooNetworkImage({
    super.key,
    this.model,
    this.id,
    this.field = 'image_128',
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.base64Data,
    this.directImageUrl,
  }) : assert(
          directImageUrl != null || (model != null && id != null),
          'Either directImageUrl must be provided, or both model and id must be provided',
        );

  String get _imageUrl {
    // If direct URL is provided, use it as-is
    if (directImageUrl != null && directImageUrl!.isNotEmpty) {
      debugPrint('OdooNetworkImage: Using direct URL - $directImageUrl');
      return directImageUrl!;
    }

    try {
      if (!OdooRpcApiManager.isAuthenticated) {
        debugPrint('OdooNetworkImage: Not authenticated');
        return '';
      }

      final state = OdooRpcApiManager.authenticationState;
      final serverUrl = state['serverUrl'] as String?;

      if (serverUrl == null || serverUrl.isEmpty) {
        debugPrint('OdooNetworkImage: No server URL available');
        return '';
      }

      // Ensure model and id are available for dynamic URL generation
      if (model == null || id == null) {
        debugPrint(
          'OdooNetworkImage: model and id are required for dynamic URL generation',
        );
        return '';
      }

      // Add session_id to URL for direct access without needing headers
      final params = <String, String>{
        'model': model!,
        'id': id!.toString(),
        'field': field,
        'session_id': OdooRpcApiManager.currentSessionId ?? '',
      };

      // Construct URL with all necessary parameters
      final uri = Uri.parse(
        serverUrl,
      ).replace(path: '/web/image', queryParameters: params);

      debugPrint('OdooNetworkImage: Generated URL - ${uri.toString()}');
      return uri.toString();
    } catch (e) {
      debugPrint('OdooNetworkImage error generating URL: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have base64 data, use it directly
    if (base64Data != null && base64Data!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(base64Data!),
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('OdooNetworkImage error decoding base64: $error');
            return _buildErrorWidget();
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: frame != null
                  ? child
                  : placeholder ??
                      Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
            );
          },
        );
      } catch (e) {
        debugPrint('OdooNetworkImage error with base64: $e');
        return _buildErrorWidget();
      }
    }

    // Otherwise use URL-based image loading
    final imageUrl = _imageUrl;
    if (imageUrl.isEmpty) {
      return _buildErrorWidget();
    }

    // For direct URLs, we might not need session authentication
    // For dynamically generated URLs, we need session authentication
    final isDirectUrl = directImageUrl != null && directImageUrl!.isNotEmpty;
    final sessionId = OdooRpcApiManager.currentSessionId;

    // If it's not a direct URL and we don't have a session, show error
    if (!isDirectUrl && sessionId == null) {
      return _buildErrorWidget();
    }

    // Prepare headers - only add session cookie if we have one and it's not a direct URL
    // or if it's a direct URL that might still need authentication
    final headers = <String, String>{};
    if (sessionId != null &&
        (!isDirectUrl || imageUrl.contains('/web/image'))) {
      headers['Cookie'] = 'session_id=$sessionId';
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      headers: headers.isNotEmpty ? headers : null,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return placeholder ??
            Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('OdooNetworkImage error loading $imageUrl: $error');
        return _buildErrorWidget();
      },
    );
  }

  Widget _buildErrorWidget() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.broken_image, color: Colors.grey[400]),
        );
  }
}
