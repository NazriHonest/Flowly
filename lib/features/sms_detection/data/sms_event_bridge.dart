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
  static final Stream<Map<Object?, Object?>> _nativeEvents = _channel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => Map<Object?, Object?>.from(event as Map))
      .asBroadcastStream();

  Stream<SmsEvent> get events => _nativeEvents
      .where((values) => values['type'] == null || values['type'] == 'sms')
      .map((values) {
        return SmsEvent(
          sender: values['sender'] as String? ?? '',
          body: values['body'] as String? ?? '',
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            values['receivedAt'] as int? ?? 0,
          ),
        );
      });

  Stream<void> get databaseChanges => _nativeEvents
      .where((values) => values['type'] == 'database_changed')
      .map<void>((_) {});
}
