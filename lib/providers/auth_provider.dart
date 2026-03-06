import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = true;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userID');
    
    if (userId != null) {
      _currentUser = await DatabaseHelper.instance.getUserById(userId);
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await DatabaseHelper.instance.getUser(email, password);
      
      if (user != null) {
        _currentUser = user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userID', user.userID!);
        
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return false;
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newUser = User(name: name, email: email, password: password);
      final savedUser = await DatabaseHelper.instance.createUser(newUser);
      
      _currentUser = savedUser;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userID', savedUser.userID!);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // likely unique constraint failure on email based on db_helper
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userID');
    notifyListeners();
  }
}
