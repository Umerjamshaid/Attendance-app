import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/services/profile_media.dart';
import 'package:attendance/services/supabase_company_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';

// Original two-frame, 1px black/white GIF, including the loop extension.
final _animatedGif = Uint8List.fromList([
  ...'GIF89a'.codeUnits,
  1,
  0,
  1,
  0,
  0x80,
  0,
  0,
  0,
  0,
  0,
  255,
  255,
  255,
  0x21,
  0xff,
  11,
  ...'NETSCAPE2.0'.codeUnits,
  3,
  1,
  0,
  0,
  0,
  0x21,
  0xf9,
  4,
  0,
  10,
  0,
  0,
  0,
  0x2c,
  0,
  0,
  0,
  0,
  1,
  0,
  1,
  0,
  0,
  2,
  2,
  0x44,
  1,
  0,
  0x21,
  0xf9,
  4,
  0,
  10,
  0,
  0,
  0,
  0x2c,
  0,
  0,
  0,
  0,
  1,
  0,
  1,
  0,
  0,
  2,
  2,
  0x4c,
  1,
  0,
  0x3b,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('profile formats are identified from bytes, not names', () {
    final samples = {
      ProfileImageFormat.jpeg: [0xff, 0xd8, 0xff, 0xe0],
      ProfileImageFormat.png: [137, 80, 78, 71, 13, 10, 26, 10],
      ProfileImageFormat.gif: _animatedGif,
      ProfileImageFormat.webp: [
        ...'RIFF'.codeUnits,
        0,
        0,
        0,
        0,
        ...'WEBP'.codeUnits,
      ],
      ProfileImageFormat.bmp: [0x42, 0x4d, 0, 0],
    };
    for (final entry in samples.entries) {
      expect(
        ProfileImageFormat.fromBytes(Uint8List.fromList(entry.value)),
        entry.key,
      );
    }
    expect(ProfileImageFormat.jpeg.extension, 'jpg');
    expect(ProfileImageFormat.gif.contentType, 'image/gif');
  });

  test('unknown, empty, and oversized profile files are rejected', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList('<svg/>'.codeUnits),
      Uint8List.fromList('not an image.jpg'.codeUnits),
    ]) {
      expect(
        () => ProfileImageFormat.fromBytes(bytes),
        throwsA(isA<CompanyException>()),
      );
    }
    final limit = Uint8List(ProfileImageFormat.maxBytes)
      ..setRange(0, _animatedGif.length, _animatedGif);
    expect(ProfileImageFormat.fromBytes(limit), ProfileImageFormat.gif);
    final tooLarge = Uint8List(ProfileImageFormat.maxBytes + 1);
    expect(
      () => ProfileImageFormat.fromBytes(tooLarge),
      throwsA(
        isA<CompanyException>().having(
          (e) => e.message,
          'message',
          contains('2 MB'),
        ),
      ),
    );
  });

  for (final kind in ['avatar', 'banner']) {
    test(
      '$kind keeps animated GIF bytes and original picker quality',
      () async {
        final picker = _Picker(
          XFile.fromData(_animatedGif, name: 'renamed.JPEG'),
        );
        final backend = _MediaBackend();
        final profile = ProfileProvider(backend: backend, picker: picker);
        addTearDown(profile.dispose);
        if (kind == 'avatar') {
          await profile.pickPfp('EMP001');
        } else {
          await profile.pickBanner('EMP001');
        }
        expect(picker.requestFullMetadata, false);
        expect(backend.kind, kind);
        expect(backend.bytes, orderedEquals(_animatedGif));
        expect(
          kind == 'avatar' ? profile.pfpPath : profile.bannerPath,
          'https://example.invalid/$kind.gif',
        );
        final codec = await ui.instantiateImageCodec(backend.bytes!);
        addTearDown(codec.dispose);
        expect(codec.frameCount, 2);
        final first = await codec.getNextFrame();
        final second = await codec.getNextFrame();
        addTearDown(first.image.dispose);
        addTearDown(second.image.dispose);
        expect(
          (await first.image.toByteData())!.getUint32(0),
          isNot((await second.image.toByteData())!.getUint32(0)),
        );
      },
    );
  }

  test(
    'cancellation and rejected input leave the old image untouched',
    () async {
      final picker = _Picker(null);
      final backend = _MediaBackend();
      final profile = ProfileProvider(backend: backend, picker: picker);
      addTearDown(profile.dispose);
      await profile.loadProfileData('EMP001');
      await profile.pickPfp('EMP001');
      expect(backend.kind, isNull);
      expect(profile.pfpPath, 'https://example.invalid/avatar.gif');
      picker.file = XFile.fromData(
        Uint8List.fromList('not a picture'.codeUnits),
        name: 'picture.png',
      );
      await expectLater(
        profile.pickPfp('EMP001'),
        throwsA(isA<CompanyException>()),
      );
      expect(backend.kind, isNull);
      expect(profile.pfpPath, 'https://example.invalid/avatar.gif');
    },
  );

  test('preview still forbids profile writes', () async {
    final picker = _Picker(XFile.fromData(_animatedGif));
    final profile = ProfileProvider(
      backend: PreviewCompanyBackend(),
      picker: picker,
    );
    addTearDown(profile.dispose);
    await expectLater(
      profile.pickPfp('DEMO001'),
      throwsA(isA<CompanyException>()),
    );
    await expectLater(
      profile.pickBanner('DEMO001'),
      throwsA(isA<CompanyException>()),
    );
    expect(picker.opened, false);
  });

  test(
    'Supabase upload preserves bytes, MIME type, extension, and ownership',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.startsWith('/storage/v1/object/')) {
            return http.Response(
              jsonEncode({'Key': request.url.path}),
              200,
              request: request,
            );
          }
          return http.Response(
            jsonEncode({'avatar_path': null, 'banner_path': null}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': 'local-test-token',
          'token_type': 'bearer',
          'user': {'id': 'owner', 'aud': 'authenticated'},
        }),
      );
      final backend = SupabaseCompanyBackend(client);
      final samples = {
        ProfileImageFormat.jpeg: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
        ProfileImageFormat.png: Uint8List.fromList([
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]),
        ProfileImageFormat.gif: _animatedGif,
        ProfileImageFormat.webp: Uint8List.fromList([
          ...'RIFF'.codeUnits,
          0,
          0,
          0,
          0,
          ...'WEBP'.codeUnits,
        ]),
        ProfileImageFormat.bmp: Uint8List.fromList([0x42, 0x4d]),
      };
      for (final kind in ['avatar', 'banner']) {
        for (final sample in samples.entries) {
          requests.clear();
          await backend.saveMedia(kind, sample.value);
          final upload = requests.first;
          expect(
            upload.url.path,
            startsWith('/storage/v1/object/profile-media/owner/$kind-'),
          );
          expect(upload.url.path, endsWith('.${sample.key.extension}'));
          expect(
            upload.headers['content-type'],
            startsWith('multipart/form-data'),
          );
          final boundary = ContentType.parse(
            upload.headers['content-type']!,
          ).parameters['boundary']!;
          final parts = await Stream<List<int>>.value(
            upload.bodyBytes,
          ).transform(MimeMultipartTransformer(boundary)).toList();
          final file = parts.singleWhere(
            (part) =>
                part.headers['content-disposition']!.contains('filename='),
          );
          expect(file.headers['content-type'], sample.key.contentType);
          expect(
            await file.expand((bytes) => bytes).toList(),
            orderedEquals(sample.value),
          );
          final update = requests.singleWhere((r) => r.method == 'PATCH');
          expect(
            jsonDecode(update.body)['${kind}_path'],
            upload.url.path.split('/profile-media/').last,
          );
        }
      }
      requests.clear();
      await expectLater(
        backend.saveMedia('avatar', Uint8List(0)),
        throwsA(isA<CompanyException>()),
      );
      expect(requests, isEmpty);
    },
  );

  test('legacy profile media keeps its local-only preference flow', () async {
    final picker = _Picker(XFile('existing-local-photo.gif'));
    final profile = ProfileProvider(picker: picker);
    addTearDown(profile.dispose);
    await profile.pickPfp('EMP001');
    await profile.pickBanner('EMP001');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('EMP001_pfp'), 'existing-local-photo.gif');
    expect(prefs.getString('EMP001_banner'), 'existing-local-photo.gif');
  });
}

class _Picker extends ImagePicker {
  _Picker(this.file);
  XFile? file;
  bool opened = false;
  bool? requestFullMetadata;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    opened = true;
    expect(source, ImageSource.gallery);
    expect(maxWidth, isNull);
    expect(maxHeight, isNull);
    expect(imageQuality, isNull);
    this.requestFullMetadata = requestFullMetadata;
    return file;
  }
}

class _MediaBackend extends PreviewCompanyBackend {
  String? kind;
  Uint8List? bytes;
  @override
  bool get isPreview => false;
  @override
  Future<void> saveMedia(String kind, Uint8List? bytes) async {
    this.kind = kind;
    this.bytes = bytes;
  }

  @override
  Future<Map<String, String?>> profileMedia() async => {
    'avatar': 'https://example.invalid/avatar.gif',
    'banner': 'https://example.invalid/banner.gif',
  };
}
