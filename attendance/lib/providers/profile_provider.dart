import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/company_backend.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({this.backend});
  final CompanyBackend? backend;
  bool _disposed = false;
  String? _pfpPath;
  String? _bannerPath;
  final ImagePicker _picker = ImagePicker();

  String? get pfpPath => _pfpPath;
  String? get bannerPath => _bannerPath;

  Future<void> loadProfileData(String userId) async {
    if (backend != null) {
      try {
        final media = await backend!.profileMedia();
        _pfpPath = media['avatar'];
        _bannerPath = media['banner'];
        notifyListeners();
      } catch (_) {
        /* Keep the last image if a refresh fails. */
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
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
      maxWidth: backend == null ? null : 1200,
      imageQuality: backend == null ? null : 85,
    );
    if (image != null) {
      if (backend != null) {
        await backend!.saveMedia('avatar', await image.readAsBytes());
        await loadProfileData(userId);
        return;
      }
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
      maxWidth: backend == null ? null : 1600,
      imageQuality: backend == null ? null : 85,
    );
    if (image != null) {
      if (backend != null) {
        await backend!.saveMedia('banner', await image.readAsBytes());
        await loadProfileData(userId);
        return;
      }
      _bannerPath = image.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${userId}_banner', _bannerPath!);
      notifyListeners();
    }
  }

  Future<void> removeBanner(String userId) async {
    if (backend != null) {
      await backend!.saveMedia('banner', null);
      await loadProfileData(userId);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${userId}_banner');
    _bannerPath = null;
    notifyListeners();
  }

  Future<void> clearProfileData() async {
    _pfpPath = null;
    _bannerPath = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
