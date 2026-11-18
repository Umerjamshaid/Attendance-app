import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/banner_color_image.dart';
import '../services/company_backend.dart';
import '../services/profile_media.dart';
import '../services/profile_image_cache.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({this.backend, this.imageViewer, ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final CompanyBackend? backend;
  final String? imageViewer;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _profileFuture;
  String? _loadingUserId;
  String? _pfpPath;
  String? _bannerPath;
  final ImagePicker _picker;

  String? get pfpPath => _pfpPath;
  String? get bannerPath => _bannerPath;

  Future<void> retryBanner(String userId) async {
    final path = _bannerPath;
    final viewer = imageViewer;
    if (path != null && viewer != null) {
      await ProfileImageCache.removeImage(path, viewer: viewer);
    }
    await loadProfileData(userId, force: true);
  }

  Future<void> loadProfileData(String userId, {bool force = false}) {
    if (_disposed) return Future<void>.value();
    final pending = _profileFuture;
    if (!force && pending != null && _loadingUserId == userId) return pending;
    final generation = ++_generation;
    late final Future<void> request;
    request = Future<void>.microtask(() => _loadProfileData(userId, generation))
        .whenComplete(() {
          if (identical(_profileFuture, request)) {
            _profileFuture = null;
            _loadingUserId = null;
          }
        });
    _profileFuture = request;
    _loadingUserId = userId;
    return request;
  }

  Future<void> _loadProfileData(String userId, int generation) async {
    if (_disposed || generation != _generation) return;
    if (backend != null) {
      try {
        final media = await backend!.profileMedia();
        if (_disposed || generation != _generation) return;
        if (media.containsKey('avatar')) _pfpPath = media['avatar'];
        if (media.containsKey('banner')) _bannerPath = media['banner'];
        notifyListeners();
      } catch (_) {
        /* Keep the last image if a refresh fails. */
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || generation != _generation) return;
    _pfpPath = prefs.getString('${userId}_pfp');
    _bannerPath = prefs.getString('${userId}_banner');
    notifyListeners();
  }

  Future<void> pickPfp(String userId) async {
    if (backend?.isPreview ?? false) {
      throw const CompanyException(
        'Profile editing is unavailable in the preview.',
      );
    }
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      // Resizing/re-encoding can flatten animated profile images.
      requestFullMetadata: false,
    );
    if (image != null) {
      if (backend != null) {
        final bytes = await image.readAsBytes();
        ProfileImageFormat.fromBytes(bytes);
        await backend!.saveMedia('avatar', bytes);
        await loadProfileData(userId, force: true);
        return;
      }
      _retireProfileLoad();
      _pfpPath = image.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${userId}_pfp', _pfpPath!);
      notifyListeners();
    }
  }

  Future<void> pickBanner(String userId) async {
    if (backend?.isPreview ?? false) {
      throw const CompanyException(
        'Profile editing is unavailable in the preview.',
      );
    }
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (image != null) {
      if (backend != null) {
        final bytes = await image.readAsBytes();
        ProfileImageFormat.fromBytes(bytes, banner: true);
        await backend!.saveMedia('banner', bytes);
        await loadProfileData(userId, force: true);
        return;
      }
      _retireProfileLoad();
      _bannerPath = image.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${userId}_banner', _bannerPath!);
      notifyListeners();
    }
  }

  Future<void> removeBanner(String userId) async {
    if (backend != null) {
      await backend!.saveMedia('banner', null);
      await loadProfileData(userId, force: true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _retireProfileLoad();
    await prefs.remove('${userId}_banner');
    _bannerPath = null;
    notifyListeners();
  }

  Future<void> setBannerColor(String userId, Color color) async {
    if (backend?.isPreview ?? false) {
      throw const CompanyException(
        'Profile editing is unavailable in the preview.',
      );
    }
    final bytes = await bannerColorPng(color);
    if (_disposed) return;
    if (backend != null) {
      await backend!.saveMedia('banner', bytes);
      await loadProfileData(userId, force: true);
      return;
    }
    final directory = await getApplicationSupportDirectory();
    final file = File(
      '${directory.path}/banner-color-${const Uuid().v4()}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    final prefs = await SharedPreferences.getInstance();
    _retireProfileLoad();
    await prefs.setString('${userId}_banner', file.path);
    if (_disposed) return;
    _bannerPath = file.path;
    notifyListeners();
  }

  Future<void> clearProfileData() async {
    _retireProfileLoad();
    _pfpPath = null;
    _bannerPath = null;
    notifyListeners();
  }

  void _retireProfileLoad() {
    ++_generation;
    _profileFuture = null;
    _loadingUserId = null;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final viewer = imageViewer;
    if (viewer != null) unawaited(ProfileImageCache.clearViewer(viewer));
    super.dispose();
  }
}
