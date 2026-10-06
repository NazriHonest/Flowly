import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/features/sms_detection/providers/automatic_detection_provider.dart';

void main() {
  test(
    'fresh install restores disabled and synchronizes native receiver',
    () async {
      final store = _MemoryStore(false);
      final platform = _FakePlatform(permission: false);
      final controller = AutomaticDetectionController(
        store: store,
        platform: platform,
      );

      expect(await controller.restored, isTrue);
      expect(controller.state, isFalse);
      expect(platform.receiverStates, [false]);
      expect(platform.permissionChecks, 0);
    },
  );

  test(
    'onboarding enable requests permission and activates runtime state',
    () async {
      final store = _MemoryStore(false);
      final platform = _FakePlatform(permission: false, requestResult: true);
      final controller = AutomaticDetectionController(
        store: store,
        platform: platform,
      );
      await controller.restored;

      expect(await controller.enableAutomaticDetection(), isTrue);
      expect(controller.state, isTrue);
      expect(store.enabled, isTrue);
      expect(platform.receiverStates, [false, true]);
      expect(platform.permissionRequests, 1);
    },
  );

  test(
    'enabled preference restores receiver and runtime listener signal',
    () async {
      final store = _MemoryStore(true);
      final platform = _FakePlatform(permission: true);
      final controller = AutomaticDetectionController(
        store: store,
        platform: platform,
      );

      expect(await controller.restoreAutomaticDetection(), isTrue);
      expect(controller.state, isTrue);
      expect(platform.receiverStates, [true]);
    },
  );

  test(
    'permission denial leaves persisted and runtime state disabled',
    () async {
      final store = _MemoryStore(false);
      final platform = _FakePlatform(permission: false, requestResult: false);
      final controller = AutomaticDetectionController(
        store: store,
        platform: platform,
      );
      await controller.restored;

      expect(await controller.enableAutomaticDetection(), isFalse);
      expect(controller.state, isFalse);
      expect(store.enabled, isFalse);
      expect(platform.receiverStates.last, isFalse);
    },
  );
}

class _MemoryStore implements AutomaticDetectionStore {
  _MemoryStore(this.enabled);
  bool enabled;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<bool> writeEnabled(bool value) async {
    enabled = value;
    return true;
  }
}

class _FakePlatform implements AutomaticDetectionPlatform {
  _FakePlatform({required this.permission, this.requestResult = false});

  bool permission;
  final bool requestResult;
  int permissionChecks = 0;
  int permissionRequests = 0;
  final List<bool> receiverStates = [];

  @override
  Future<bool> permissionGranted() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<void> synchronizeReceiver(bool enabled) async {
    receiverStates.add(enabled);
  }
}
