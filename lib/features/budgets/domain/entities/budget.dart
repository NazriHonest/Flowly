class Budget {
  const Budget({
    this.id,
    required this.name,
    required this.category,
    required this.amountMinor,
    this.period = 'monthly',
    this.startDate,
    this.alertThreshold = .8,
    this.archived = false,
  });
  final int? id;
  final String name;
  final String category;
  final int amountMinor;
  final String period;
  final DateTime? startDate;
  final double alertThreshold;
  final bool archived;
}
