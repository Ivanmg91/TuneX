import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();

  // Controladores para leer el texto
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isRegistering = false; // ¿Está intentando registrarse o loguearse?
  String _errorMessage = '';

  Future<void> _submit() async {
    setState(() => _errorMessage = ''); // Limpiar errores

    try {
      if (_isRegistering) {
        // REGISTRO
        await _auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // LOGIN
        await _auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      // Si todo va bien, el 'Stream' del main.dart nos llevará a la Home automáticamente
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo o Icono
              const Icon(Icons.music_note, size: 80, color: Color(0xFF1DB954)),
              const SizedBox(height: 20),
              const Text(
                'TuneX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Campo Email
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 20),

              // Campo Contraseña
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                ),
              ),

              // Mensaje de Error (si lo hay)
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 30),

              // Botón Principal (Entrar/Registrar)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    _isRegistering ? 'CREAR CUENTA' : 'INICIAR SESIÓN',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botón para cambiar modo
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = !_isRegistering;
                    _errorMessage = '';
                  });
                },
                child: Text(
                  _isRegistering
                      ? '¿Ya tienes cuenta? Inicia Sesión'
                      : '¿Eres nuevo? Regístrate',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
