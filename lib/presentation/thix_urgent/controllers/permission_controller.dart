// lib/presentation/thix_urgent/controllers/permission_controller.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionController extends ChangeNotifier {
  bool mic = false, camera = false, location = false;
  bool _askedBefore = false;

  Future<void> checkAll() async {
    final prefs = await SharedPreferences.getInstance();
    _askedBefore = prefs.getBool('perm_asked') ?? false;
    mic = await Permission.microphone.isGranted;
    camera = await Permission.camera.isGranted;
    location = await Permission.location.isGranted;
    notifyListeners();
  }

  Future<void> requestAll() async {
    if (_askedBefore && !mic && !camera) {
      if (await Permission.microphone.status == PermissionStatus.permanentlyDenied) return;
    }
    final statuses = await [Permission.microphone, Permission.camera, Permission.location].request();
    mic = statuses[Permission.microphone]?.isGranted ?? false;
    camera = statuses[Permission.camera]?.isGranted ?? false;
    location = statuses[Permission.location]?.isGranted ?? false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('perm_asked', true);
    notifyListeners();
  }
}
