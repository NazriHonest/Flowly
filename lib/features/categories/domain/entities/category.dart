class Category {
  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.type = 'expense',
    this.archived = false,
    this.createdAt,
    this.updatedAt,
  });
  final int? id;
  final String name;
  final String type;
  final int icon;
  final int color;
  final bool archived;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
