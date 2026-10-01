import 'package:flutter/services.dart';

/// Inbox rows are exposed only during an explicit import and must be processed
/// and discarded in the same operation. They are never stored by this bridge.
class HistoricalSmsBridge {
  const HistoricalSmsBridge();
  static const _channel = MethodChannel('com.flowly/sms_permissions');

  Future<List<HistoricalSmsMessage>> read() async {
    final rows =
        await _channel.invokeListMethod<Object?>('historical') ?? const [];
    return rows.whereType<Map>().map((row) {
      final values = Map<Object?, Object?>.from(row);
      return HistoricalSmsMessage(
        sender: values['sender'] as String? ?? '',
        body: values['body'] as String? ?? '',
        receivedAt: DateTime.fromMillisecondsSinceEpoch(
          values['receivedAt'] as int? ?? 0,
        ),
      );
    }).toList();
  }
}

class HistoricalSmsMessage {
  const HistoricalSmsMessage({
    required this.sender,
    required this.body,
    required this.receivedAt,
  });
  final String sender;
  final String body;
  final DateTime receivedAt;
}
