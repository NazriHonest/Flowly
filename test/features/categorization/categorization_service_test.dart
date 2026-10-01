import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/features/categorization/domain/services/categorization_service.dart';

void main() {
  const service = CategorizationService();
  test('merchant rules take priority over generic keywords', () {
    expect(
      service.suggest(
        merchant: 'City Market',
        merchantRules: const [MerchantRule('city market', 'Shopping')],
        keywordRules: const [KeywordRule('market', 'Groceries')],
      ),
      'Shopping',
    );
  });
  test('generic keyword categorization is deterministic', () {
    expect(
      service.suggest(
        merchant: 'Local Supermarket',
        merchantRules: const [],
        keywordRules: const [],
      ),
      'Groceries',
    );
  });
}
