import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:attendance/services/profile_cache_cleanup.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String> getTemporaryPath() async => path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'failed namespaces survive restart and are removed only after successful cleanup',
    () async {
      const namespace = 'profile-media-v1-viewer';
      final failed = ProfileCacheCleanup(
        purge: (_) async => throw const FileSystemException('Locked'),
      );
      await failed.remember(namespace);
      await failed.retry();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(ProfileCacheCleanup.pendingKey), [namespace]);

      final purged = <String>[];
      final restarted = ProfileCacheCleanup(
        purge: (name) async => purged.add(name),
      );
      expect(await restarted.namespaceFor('viewer'), isNot(namespace));
      await restarted.retry();
      expect(purged, [namespace]);
      expect(prefs.getStringList(ProfileCacheCleanup.pendingKey), isEmpty);
      expect(await restarted.namespaceFor('viewer'), namespace);
    },
  );

  test(
    'a pending purge neither blocks a new namespace nor loses concurrent failures',
    () async {
      const first = 'profile-media-v1-first';
      const second = 'profile-media-v1-second';
      SharedPreferences.setMockInitialValues({
        ProfileCacheCleanup.pendingKey: [first, '../outside-cache'],
      });
      final started = Completer<void>();
      final release = Completer<void>();
      final queue = ProfileCacheCleanup(
        purge: (name) async {
          if (!started.isCompleted) started.complete();
          await release.future;
        },
      );
      final pending = queue.retry();
      await started.future;
      expect(await queue.namespaceFor('first'), isNot(first));
      expect(await queue.namespaceFor('other'), 'profile-media-v1-other');
      await queue.remember(second);
      expect(identical(queue.retry(), pending), isTrue);
      release.complete();
      await pending;
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(ProfileCacheCleanup.pendingKey), [second]);
      await queue.retry();
      expect(prefs.getStringList(ProfileCacheCleanup.pendingKey), isEmpty);
    },
  );

  test(
    'retry purges indexed and partial files without touching another namespace',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'attendance-purge-queue-',
      );
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = original;
        await directory.delete(recursive: true);
      });
      const retired = 'profile-media-v1-retired';
      final manager = CacheManager(Config(retired));
      final indexed = await manager.putFile(
        'old-avatar',
        Uint8List.fromList([1]),
        key: 'old-avatar',
      );
      await manager.dispose();
      final partial = await IOFileSystem(retired).createFile('partial-image');
      await partial.writeAsBytes([2]);
      final active = await IOFileSystem(
        'profile-media-v1-active',
      ).createFile('current-image');
      await active.writeAsBytes([3]);
      final queue = ProfileCacheCleanup();
      await queue.remember(retired);
      await queue.retry();
      expect(await indexed.exists(), isFalse);
      expect(await partial.exists(), isFalse);
      expect(await active.readAsBytes(), [3]);
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          ProfileCacheCleanup.pendingKey,
        ),
        isEmpty,
      );
    },
  );
}
