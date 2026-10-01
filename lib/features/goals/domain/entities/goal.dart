class Goal {
  const Goal({
    this.id,
    required this.name,
    required this.targetMinor,
    this.currentMinor = 0,
    this.targetDate,
    this.accountId,
  });
  final int? id, accountId;
  final String name;
  final int targetMinor, currentMinor;
  final DateTime? targetDate;
  int get remainingMinor => targetMinor - currentMinor;
  double get progress => targetMinor == 0 ? 0 : currentMinor / targetMinor;
}
