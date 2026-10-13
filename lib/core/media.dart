import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'theme.dart';

/// The API returns absolute media URLs built from its public URL. On a development machine that is "localhost",
/// which a phone cannot reach, so loopback hosts are pointed at the API host the app is talking to.
String? mediaUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final api = Uri.parse(AppConfig.apiUrl);
  // Some admin payloads (branches) carry the stored relative path ("/static/legacy/x.webp").
  if (url.startsWith('/')) return api.resolve(url).toString();
  final u = Uri.tryParse(url);
  if (u == null || !const ['localhost', '127.0.0.1', '10.0.2.2'].contains(u.host)) return url;
  return u.replace(scheme: api.scheme, host: api.host, port: api.port).toString();
}

/// Rounded photo with a tinted icon while loading or when there is no photo.
class Photo extends StatelessWidget {
  const Photo(this.url, {super.key, this.size = 64, this.radius = 12, this.icon = Icons.restaurant});
  final String? url;
  final double size;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Brand.tomato.withValues(alpha: 0.08),
      child: Icon(icon, color: Brand.tomato.withValues(alpha: 0.6), size: size * 0.42),
    );
    final src = mediaUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: src == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: src,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: (size * 3).round(),
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}
