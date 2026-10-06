class SmsProvider {
  const SmsProvider({
    this.id,
    required this.name,
    this.senderAliases = const [],
    this.enabled = true,
  });
  final int? id;
  final String name;
  final List<String> senderAliases;
  final bool enabled;
}

class ProviderAccountMapping {
  const ProviderAccountMapping({
    this.id,
    required this.providerId,
    required this.accountId,
    this.linkedAccountId,
  });
  final int? id, providerId, accountId, linkedAccountId;
}
