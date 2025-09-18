import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A service class to handle all Firebase Authentication and user management logic.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// A stream that notifies the app about real-time authentication changes.
  Stream<User?> get user => _auth.authStateChanges();

  // --- REGULAR USER FUNCTIONS ---

  /// Signs in a user with their email and password.
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("Error signing in with email: ${e.message}");
      return null;
    }
  }

  /// Signs in a user with their Google account.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // The user canceled the sign-in flow.

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user != null && result.additionalUserInfo!.isNewUser) {
        _createNewUserRecord(user);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print("Error signing in with Google: ${e.message}");
      return null;
    }
  }

  /// Registers a new user with email, password, and a username.
  Future<User?> registerWithEmailAndPassword(String email, String password, String username) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = result.user;

      if (user != null) {
        await user.updateDisplayName(username);
        await user.reload();
        _createNewUserRecord(_auth.currentUser!);
      }
      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      print("Error registering user: ${e.message}");
      return null;
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  /// Changes the current user's password.
  Future<String> changePassword(String newPassword) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return "No user is currently signed in.";
      }
      await currentUser.updatePassword(newPassword);
      return "Success";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "An unknown error occurred.";
    }
  }

  /// ✅ NEW: Sends a password reset link to the provided email.
  Future<String> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return "Success"; // Return a success message
    } on FirebaseAuthException catch (e) {
      // This will catch common errors, like "user-not-found".
      return e.message ?? "An unknown error occurred.";
    }
  }

  // --- ADMIN-SPECIFIC FUNCTIONS ---

  /// Checks if the currently logged-in user is an administrator.
  Future<bool> isAdmin() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    return currentUser.email == 'milanpullukattu9760@gmail.com';
  }

  /// Updates a user's display name (for an admin).
  Future<void> updateUserDetails(String uid, String newDisplayName) async {
    try {
      await _db.collection('users').doc(uid).update({'displayName': newDisplayName});
    } catch (e) {
      print("Error updating user details: $e");
      rethrow;
    }
  }

  /// Deletes a user's data document from Firestore (for an admin).
  Future<void> deleteUserData(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      print("Error deleting user data: $e");
      rethrow;
    }
  }

  /// Gets a real-time stream of all users for the admin dashboard.
  Stream<QuerySnapshot> getAllUsers() {
    return _db.collection('users').snapshots();
  }

  // --- PRIVATE HELPER FUNCTION ---

  /// Creates a new document in the 'users' collection when a user signs up.
  Future<void> _createNewUserRecord(User user) {
    return _db.collection('users').doc(user.uid).set({
      'displayName': user.displayName,
      'email': user.email,
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}