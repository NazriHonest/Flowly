class FinancialMessageDetector {
  const FinancialMessageDetector();
  bool isPotentialFinancialMessage(String sender, String message) {
    if (sender.trim().isEmpty || message.trim().isEmpty) return false;
    final text = message.toLowerCase();
    // Provider-specific Somali messages do not necessarily contain the
    // English keywords used by the generic detector. Their explicit markers
    // and transaction phrases are sufficient evidence for the dedicated
    // parsers and must be recognized before generic filtering.
    if (text.contains('[-evcplus-]') ||
        text.contains('[-jeeb-]') ||
        RegExp(r'ayaad\s+(?:uwareejisay|ka\s+heshay|u\s+dirtay)',
                caseSensitive: false)
            .hasMatch(text)) {
      return RegExp(r'\d').hasMatch(text);
    }
    return RegExp(
          r'\b(paid|payment|sent|received|deposit|withdrawal|transfer)\b',
        ).hasMatch(text) &&
        RegExp(r'\d').hasMatch(text);
  }
}
