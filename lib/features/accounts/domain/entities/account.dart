class Account {
  const Account({
    this.id,
    required this.name,
    required this.openingBalanceMinor,
    this.color = 0xFF079669,
    this.icon = 0xe850,
    this.type = 'cash',
    this.currency = 'KES',
    this.providerId,
    this.archived = false,
  });
  final int? id;
  final String name;
  final int openingBalanceMinor, color, icon;
  final String type, currency;
  final int? providerId;
  final bool archived;
}
