import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/database.dart';
import '../services/sync_service.dart';

enum UserRole { admin, cashier }

class UserProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppDatabase db;
  User? _user;
  SyncService? syncService;
  UserRole _activeRole = UserRole.admin;
  
  UserProvider(this.db) {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        syncService?.dispose();
        syncService = SyncService(db: db, shopId: user.uid);
      } else {
        syncService?.dispose();
        syncService = null;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  String? get shopId => _user?.uid;
  UserRole get activeRole => _activeRole;

  bool switchRole(UserRole role, {String? pin}) {
    if (role == UserRole.admin) {
      if (pin == '1234') {
        _activeRole = role;
        notifyListeners();
        return true;
      }
      return false;
    } else {
      _activeRole = role;
      notifyListeners();
      return true;
    }
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (userCredential.user != null) {
      await db.insertStarterInventory();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
