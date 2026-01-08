import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtener usuario actual
  User? get currentUser => _auth.currentUser;

  // Stream para detectar cambios de estado (si entra o sale)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. Iniciar Sesión (Login)
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // 2. Registrarse (Sign Up) y crear ficha en Base de Datos
  Future<void> signUp({required String email, required String password}) async {
    // A. Crear la cuenta de autenticación
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // B. Crear el documento del usuario en la Base de Datos
    // Aquí es donde definimos que por defecto es "user" (no artista)
    if (result.user != null) {
      await _db.collection('users').doc(result.user!.uid).set({
        'email': email,
        'role': 'user', // Roles posibles: 'user', 'artist', 'admin'
        'artistStatus': 'none', // Estados: 'none', 'pending', 'approved'
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // 3. Cerrar Sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
