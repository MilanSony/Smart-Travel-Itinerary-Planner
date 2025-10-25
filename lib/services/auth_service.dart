import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

  // --- NEW: Added the missing password reset function back ---
  Future<String> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return "Success";
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      }
      return e.message ?? "An unknown error occurred.";
    }
  }

  Future<bool> isAdmin() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.email == 'milanpullukattu9760@gmail.com') {
      return true;
    }
    return false;
  }

  Future<User?> registerWithEmailAndPassword(String email, String password, String username) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await result.user?.updateDisplayName(username);

      await _db.collection('users').doc(result.user!.uid).set({
        'displayName': username,
        'email': email,
        'uid': result.user!.uid,
      });

      await result.user?.reload();
      return _auth.currentUser;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential result = await _auth.signInWithCredential(credential);

      final userDoc = await _db.collection('users').doc(result.user!.uid).get();
      if (!userDoc.exists) {
        await _db.collection('users').doc(result.user!.uid).set({
          'displayName': result.user!.displayName,
          'email': result.user!.email,
          'uid': result.user!.uid,
        });
      }
      return result.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> updateUserDetails(String uid, String newDisplayName) async {
    try {
      await _db.collection('users').doc(uid).update({
        'displayName': newDisplayName,
      });
    } catch (e) {
      print("Error updating user details: $e");
    }
  }

  Future<void> deleteUserData(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      print("Error deleting user data: $e");
    }
  }

  Future<String> changePassword(String newPassword) async {
    try {
      await _auth.currentUser!.updatePassword(newPassword);
      return "Success";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "An unknown error occurred.";
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: ${e.toString()}');
    }
  }
}