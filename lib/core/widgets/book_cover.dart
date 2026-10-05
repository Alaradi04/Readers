import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.picture,
    required this.width,
    required this.height,
  });

  final String? picture;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = picture?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        height: height,
        color: AppTheme.mint,
        alignment: Alignment.center,
        child: imageUrl.isEmpty
            ? const Icon(Icons.menu_book_rounded, color: AppTheme.forest)
            : Image.network(
                imageUrl,
                width: width,
                height: height,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.menu_book_rounded, color: AppTheme.forest),
              ),
      ),
    );
  }
}
