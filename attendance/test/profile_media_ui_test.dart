import 'dart:convert';
import 'dart:io';

import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/profile_image_cache.dart';
import 'package:attendance/widgets/profile_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:attendance/widgets/user-profile/profile_header.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/test_fonts.dart';
import 'support/overview_fonts.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('thumbnail decoding uses the displayed width and density', (
    tester,
  ) async {
    late ImageProvider<Object> thumbnail;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2.625),
        child: Builder(
          builder: (context) {
            thumbnail = profileImageProvider(
              'https://example.invalid/profile.png',
              width: profileDecodeWidth(context, 42),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect((thumbnail as ResizeImage).width, 111);
  });

  testWidgets(
    'a failed banner exposes retry rather than only a silent fallback',
    (tester) async {
      final profile = _Profile();
      addTearDown(profile.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ProfileProvider>.value(
          value: profile,
          child: MaterialApp(
            theme: AppTheme.theme,
            home: Scaffold(
              body: ListView(
                children: [
                  ProfileHeader(
                    employee: Employee(
                      id: 'EMP001',
                      name: 'Sample Employee',
                      email: '',
                      department: '',
                      role: 'employee',
                      time: '',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _pumpUntil(
        tester,
        () => find.byTooltip('Retry banner').evaluate().isNotEmpty,
      );
      expect(find.byTooltip('Retry banner'), findsOneWidget);
      await tester.tap(find.byTooltip('Retry banner'));
      await tester.pumpAndSettle();
      expect(profile.bannerRetries, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'signature refresh clears Retry and outgoing banner errors are ignored',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('attendance-banner-race-'),
      ))!;
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      const viewer = 'banner-race';
      const first =
          'https://photos.example.invalid/storage/v1/object/sign/profile-media/owner/banner-v1.gif?token=old';
      const rotated =
          'https://photos.example.invalid/storage/v1/object/sign/profile-media/owner/banner-v1.gif?token=new';
      const replacement =
          'https://photos.example.invalid/storage/v1/object/sign/profile-media/owner/banner-v2.gif?token=new';
      final avatar = first.replaceFirst('banner-v1', 'avatar-v1');
      final profile = _Profile(imageViewer: viewer)
        ..replaceBanner(first)
        ..replaceAvatar(avatar);
      addTearDown(() async {
        await tester.runAsync(() async {
          profile.dispose();
          await ProfileImageCache.clearViewer(viewer);
          PathProviderPlatform.instance = original;
          await directory.delete(recursive: true);
        });
      });
      for (final url in [first, replacement, avatar]) {
        await tester.runAsync(() async {
          final image = ProfileImageCache.image(
            url,
            viewer: viewer,
          ) as CachedNetworkImageProvider;
          await image.cacheManager!.putFile(
            url,
            base64Decode(
              'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
            ),
            key: image.cacheKey,
            fileExtension: 'gif',
          );
        });
      }
      await tester.pumpWidget(
        ChangeNotifierProvider<ProfileProvider>.value(
          value: profile,
          child: MaterialApp(
            theme: AppTheme.theme,
            home: Scaffold(
              body: ProfileHeader(
                employee: Employee(
                  id: 'EMP001',
                  name: 'Sample Employee',
                  email: '',
                  department: '',
                  role: 'employee',
                  time: '',
                ),
              ),
            ),
          ),
        ),
      );
      await _pumpUntil(
        tester,
        () =>
            find
                .byType(RawImage)
                .evaluate()
                .where((element) => (element.widget as RawImage).image != null)
                .length ==
            2,
      );
      final bannerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is ResizeImage &&
            (widget.image as ResizeImage).width == 1080,
      );
      final avatarFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is ResizeImage &&
            (widget.image as ResizeImage).imageProvider
                is CachedNetworkImageProvider &&
            ((widget.image as ResizeImage).imageProvider
                        as CachedNetworkImageProvider)
                    .cacheKey
                    ?.contains('avatar-v1') ==
                true,
      );
      final firstElement = tester.element(bannerFinder);
      final avatarElement = tester.element(avatarFinder);
      final firstImage = tester.widget<Image>(bannerFinder);
      firstImage.errorBuilder!(
        firstElement,
        StateError('Initial failure'),
        null,
      );
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Retry banner'), findsOneWidget);
      profile.replaceBanner(rotated);
      profile.replaceAvatar(avatar.replaceFirst('token=old', 'token=new'));
      await tester.pump();
      expect(find.byTooltip('Retry banner'), findsNothing);
      expect(
        tester.element(bannerFinder),
        same(firstElement),
        reason: 'signature rotation keeps the stable image element',
      );
      expect(
        tester.element(avatarFinder),
        same(avatarElement),
        reason: 'avatar signature rotation must not restart its transition',
      );
      final outgoing = tester.widget<Image>(bannerFinder);
      profile.replaceBanner(replacement);
      await tester.pump();
      expect(
        bannerFinder,
        findsNWidgets(2),
        reason: 'outgoing image remains during the transition',
      );
      outgoing.errorBuilder!(
        firstElement,
        StateError('Late outgoing failure'),
        null,
      );
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Retry banner'), findsNothing);
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () =>
            find
                .byType(RawImage)
                .evaluate()
                .where((element) => (element.widget as RawImage).image != null)
                .length ==
            2,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('profile media icons fit ${brightness.name} UI', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final profile = _Profile();
      addTearDown(profile.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ProfileProvider>.value(
          value: profile,
          child: MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.darkTheme
                : AppTheme.theme,
            home: Scaffold(
              body: ListView(
                children: [
                  ProfileHeader(
                    employee: Employee(
                      id: 'EMP001',
                      name: 'Sample Employee',
                      email: 'sample@example.invalid',
                      department: 'Engineering',
                      role: 'employee',
                      time: '',
                      headline: 'Building with the team',
                      chips: const ['Mentor', 'Flutter'],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Icon>(find.byIcon(AppIcons.cameraPlus)).size, 16);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.camera)).size, 18);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.trash)).size, 18);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.idBadge2)).size, 16);
      final name = tester.widget<Text>(find.text('Sample Employee'));
      expect(name.style?.fontFamily, ProfileUi.fontFamily);
      expect(
        Theme.of(tester.element(find.text('Sample Employee')))
            .textTheme
            .bodyLarge
            ?.fontFamily,
        ProfileUi.fontFamily,
      );
      final remove = find.bySemanticsLabel('Remove cover photo');
      expect(tester.getSize(remove).shortestSide, greaterThanOrEqualTo(44));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/profile_media_${brightness.name}.png'),
      );
      tester.view.physicalSize = const Size(320, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(AppIcons.cameraPlus));
      await tester.pumpAndSettle();
      expect(find.text('Choose an image no larger than 5 MB.'), findsOneWidget);
    });
  }

  testWidgets('profile font does not change shared Home and History type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (context) {
            final normal = ProfileUi.body(context, weight: FontWeight.w600);
            expect(normal.fontFamily, startsWith('Inter'));
            expect(normal.height, 1.25);
            return Theme(
              data: ProfileUi.themeOf(context),
              child: Builder(
                builder: (context) {
                  final profile = ProfileUi.body(
                    context,
                    weight: FontWeight.w600,
                  );
                  expect(profile.fontFamily, ProfileUi.fontFamily);
                  expect(profile.height, 1.25);
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );
  });

  test('attendance counter digits keep equal advance widths', () {
    final style = GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    double width(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    expect(width('1111'), closeTo(width('8888'), 0.01));
  });
}

class _Profile extends ProfileProvider {
  _Profile({super.imageViewer});
  String? _banner = 'missing-test-banner.png';
  String? _avatar;
  void replaceAvatar(String path) {
    _avatar = path;
    notifyListeners();
  }

  @override
  String? get pfpPath => _avatar;
  void replaceBanner(String? path) {
    _banner = path;
    notifyListeners();
  }

  int bannerRetries = 0;
  @override
  Future<void> retryBanner(String userId) async {
    bannerRetries++;
  }

  @override
  String? get bannerPath => _banner;

  @override
  Future<void> pickPfp(String userId) async =>
      throw const CompanyException('Choose an image no larger than 5 MB.');
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(
    ready(),
    isTrue,
    reason: 'expected UI state did not appear before timeout',
  );
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String> getTemporaryPath() async => path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}
