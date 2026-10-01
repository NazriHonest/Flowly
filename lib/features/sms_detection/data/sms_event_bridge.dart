import 'dart:async';

import 'package:flutter/services.dart';

/// Native events are transient. Consumers must parse and discard [body]; they
/// must never save it in preferences, SQLite, files, logs, or backups.
class SmsEvent {
  const SmsEvent({
    required this.sender,
    required this.body,
    required this.receivedAt,
  });
  final String sender;
  final String body;
  final DateTime receivedAt;
}

class SmsEventBridge {
  static const _channel = EventChannel('com.flowly/sms_events');
  Stream<SmsEvent> get events => _channel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) {
        final values = Map<Object?, Object?>.from(event as Map);
        return SmsEvent(
          sender: values['sender'] as String? ?? '',
          body: values['body'] as String? ?? '',
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            values['receivedAt'] as int? ?? 0,
          ),
        );
      });
}
