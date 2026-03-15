import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';

class AuthNotifier extends ChangeNotifier {
  User? _user;
  User? get user => _user;

  void loginAsParent() {
    _user = const User(
      id: 'senior_001',
      role: 'parent',
      name: 'Mr. Sharma',
      phone: '+91 98765 43210',
    );
    notifyListeners();
  }

  void loginAsChild() {
    _user = const User(
      id: 'child_001',
      role: 'child',
      name: 'Arjun Sharma',
      phone: '+1 416 555 0123',
      email: 'arjun@example.com',
    );
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

final authProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});
