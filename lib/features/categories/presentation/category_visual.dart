import 'package:flutter/material.dart';

import '../domain/entities/category.dart';

class CategoryVisual {
  const CategoryVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

CategoryVisual resolveCategoryVisual(
  Iterable<Category> categories,
  String categoryName, {
  required Color fallbackColor,
  IconData fallbackIcon = Icons.category_outlined,
}) {
  final normalized = categoryName.trim().toLowerCase();
  for (final category in categories) {
    if (category.name.trim().toLowerCase() == normalized) {
      return CategoryVisual(
        // Category icons are persisted Material icon code points.
        // ignore: non_const_argument_for_const_parameter
        icon: IconData(category.icon, fontFamily: 'MaterialIcons'),
        color: Color(category.color),
      );
    }
  }
  return CategoryVisual(icon: fallbackIcon, color: fallbackColor);
}
