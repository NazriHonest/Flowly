class CategorizationService {
  const CategorizationService();
  String suggest({
    required String merchant,
    required Iterable<MerchantRule> merchantRules,
    required Iterable<KeywordRule> keywordRules,
  }) {
    final normalized = normalizeMerchant(merchant);
    for (final rule in merchantRules) {
      if (normalizeMerchant(rule.merchant) == normalized) return rule.category;
    }
    for (final rule in keywordRules) {
      if (normalized.contains(normalizeMerchant(rule.keyword))) {
        return rule.category;
      }
    }
    if (RegExp(r'\b(supermarket|grocery|market)\b').hasMatch(normalized)) {
      return 'Groceries';
    }
    if (RegExp(r'\b(taxi|fuel|bus)\b').hasMatch(normalized)) return 'Transport';
    return 'Other';
  }
}

/// A display name can retain its casing; matching always uses this local,
/// privacy-safe key. Phone-only values are excluded by provider parsers.
String normalizeMerchant(String merchant) =>
    merchant.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class MerchantRule {
  const MerchantRule(this.merchant, this.category);
  final String merchant, category;
}

class KeywordRule {
  const KeywordRule(this.keyword, this.category);
  final String keyword, category;
}
