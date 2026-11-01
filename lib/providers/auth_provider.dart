import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class AuthNotifier extends StateNotifier<UserModel?> {
  static const String _sessionKey = 'saved_user_session';

  AuthNotifier() : super(null) {
    _initCurrentUser();
  }

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<UserModel?> restoreSavedSession() async {
    // 1. Restore local session from SharedPreferences first
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_sessionKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final user = UserModel.fromMap(map, map['id'] ?? 'user-temp');
        state = user;
      }
    } catch (_) {}

    // 2. Sync with FirebaseAuth current user if online / ready
    if (_isFirebaseReady) {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        if (state != null) {
          // We already have cached session; refresh in background without blocking UI startup
          fetchUserData(firebaseUser.uid);
          return state;
        }
        try {
          final fetchedUser = await fetchUserData(firebaseUser.uid).timeout(const Duration(seconds: 3));
          if (fetchedUser != null) {
            await _saveSession(fetchedUser);
            state = fetchedUser;
            return fetchedUser;
          }
        } catch (_) {}
      }
    }

    return state;
  }

  Future<void> _initCurrentUser() async {
    await restoreSavedSession();
  }

  Future<void> _saveSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(user.toMap()));
    } catch (_) {}
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }

  Future<UserModel?> fetchUserData(String uid) async {
    if (!_isFirebaseReady) return null;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final userModel = UserModel.fromMap(doc.data()!, doc.id);
        state = userModel;
        await _saveSession(userModel);
        return userModel;
      }
    } catch (_) {
      // Ignored if offline
    }
    return null;
  }

  Future<UserModel> signIn({required String email, required String password}) async {
    if (!_isFirebaseReady) {
      // Offline / Test fallback
      final mockRole = email.toLowerCase().contains('admin') ? 'admin' : 'user';
      final fallbackUser = UserModel(
        id: 'user-temp',
        firstName: email.split('@').first,
        lastName: '',
        email: email,
        role: mockRole,
        bankAccount: '',
      );
      state = fallbackUser;
      await _saveSession(fallbackUser);
      return fallbackUser;
    }

    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    final existingUser = await fetchUserData(uid);

    if (existingUser != null) {
      state = existingUser;
      await _saveSession(existingUser);
      return existingUser;
    }

    // Default if document not yet created
    final isEmailAdmin = email.toLowerCase().contains('admin');
    final newUser = UserModel(
      id: uid,
      firstName: credential.user!.displayName ?? email.split('@').first,
      lastName: '',
      email: email,
      role: isEmailAdmin ? 'admin' : 'user',
      bankAccount: '',
    );

    await FirebaseFirestore.instance.collection('users').doc(uid).set(newUser.toMap());
    state = newUser;
    await _saveSession(newUser);
    return newUser;
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String nickname = '',
    required String bankAccount,
    String? profileImage,
    String role = 'user',
  }) async {
    final isEmailAdmin = email.toLowerCase().contains('admin') || role == 'admin';

    if (!_isFirebaseReady) {
      final fallbackUser = UserModel(
        id: 'user-${DateTime.now().millisecondsSinceEpoch}',
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        nickname: nickname.trim(),
        email: email.trim(),
        role: isEmailAdmin ? 'admin' : 'user',
        bankAccount: bankAccount.trim(),
        profileImage: profileImage,
      );
      state = fallbackUser;
      await _saveSession(fallbackUser);
      return;
    }

    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    final newUser = UserModel(
      id: uid,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      nickname: nickname.trim(),
      email: email.trim(),
      role: isEmailAdmin ? 'admin' : 'user',
      bankAccount: bankAccount.trim(),
      profileImage: profileImage,
    );

    // Save to Cloud Firestore Realtime
    await FirebaseFirestore.instance.collection('users').doc(uid).set(newUser.toMap());
    state = newUser;
    await _saveSession(newUser);
  }

  Future<void> resetPassword(String email) async {
    if (email.trim().isEmpty) return;
    if (_isFirebaseReady) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    }
  }

  Future<UserModel> signInWithGoogle() async {
    if (!_isFirebaseReady) {
      final googleUser = UserModel(
        id: 'google-user-${DateTime.now().millisecondsSinceEpoch}',
        firstName: 'Google',
        lastName: 'User',
        nickname: 'GoogleUser',
        email: 'user.google@gmail.com',
        role: 'user',
        bankAccount: '',
      );
      state = googleUser;
      await _saveSession(googleUser);
      return googleUser;
    }

    try {
      final googleProvider = GoogleAuthProvider();
      final credential = await FirebaseAuth.instance.signInWithProvider(googleProvider);
      final uid = credential.user!.uid;
      final email = credential.user!.email ?? 'google_user@gmail.com';
      final displayName = credential.user!.displayName ?? 'Google User';
      final photoUrl = credential.user!.photoURL;

      final existingUser = await fetchUserData(uid);
      if (existingUser != null) {
        state = existingUser;
        await _saveSession(existingUser);
        return existingUser;
      }

      final isEmailAdmin = email.toLowerCase().contains('admin');
      final nameParts = displayName.split(' ');
      final newUser = UserModel(
        id: uid,
        firstName: nameParts.first,
        lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
        nickname: nameParts.first,
        email: email,
        role: isEmailAdmin ? 'admin' : 'user',
        bankAccount: '',
        profileImage: photoUrl,
      );

      await FirebaseFirestore.instance.collection('users').doc(uid).set(newUser.toMap());
      state = newUser;
      await _saveSession(newUser);
      return newUser;
    } catch (_) {
      final googleUser = UserModel(
        id: 'google-user-temp',
        firstName: 'Google',
        lastName: 'User',
        nickname: 'GoogleUser',
        email: 'user.google@gmail.com',
        role: 'user',
        bankAccount: '',
      );
      state = googleUser;
      await _saveSession(googleUser);
      return googleUser;
    }
  }

  Future<void> updateUserProfile(UserModel updatedUser) async {
    state = updatedUser;
    await _saveSession(updatedUser);
    await firestoreService.saveUser(updatedUser);
  }

  Future<void> signOut() async {
    await _clearSession();
    if (_isFirebaseReady) {
      await FirebaseAuth.instance.signOut();
    }
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier();
});

final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return firestoreService.usersStream();
});
