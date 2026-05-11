import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider extends ChangeNotifier {
  String? _pfpPath;
  String? _bannerPath;
  final ImagePicker _picker = ImagePicker();

  String? get pfpPath => _pfpPath;
  String? get bannerPath => _bannerPath;

  Future<void> loadProfileData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    _pfpPath = prefs.getString('${userId}_pfp');
    _bannerPath = prefs.getString('${userId}_banner');
    notifyListeners();
  }

  Future<void> pickPfp(String userId) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _pfpPath = image.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${userId}_pfp', _pfpPath!);
      notifyListeners();
    }
  }

  Future<void> pickBanner(String userId) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _bannerPath = image.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${userId}_banner', _bannerPath!);
      notifyListeners();
    }
  }

  Future<void> clearProfileData() async {
    _pfpPath = null;
    _bannerPath = null;
    notifyListeners();
  }
}
