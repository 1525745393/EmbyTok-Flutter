import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/image_cache_manager.dart';

class PersonAvatarImage extends StatelessWidget {
  final String? imageUrl;
  final Map<String, String>? httpHeaders;
  final double size;
  final int? memCacheWidth;

  const PersonAvatarImage({
    super.key,
    required this.imageUrl,
    this.httpHeaders,
    required this.size,
    this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder(context);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      cacheManager: AppImageCacheManager.thumbnail,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 300),
      memCacheWidth: memCacheWidth ?? (size * 2).round(),
      httpHeaders: httpHeaders?.isNotEmpty == true ? httpHeaders : null,
      placeholder: (_, __) => _buildPlaceholder(context),
      errorWidget: (_, __, ___) => _buildPlaceholder(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Icon(
      Icons.person,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      size: size * 0.5,
    );
  }
}
