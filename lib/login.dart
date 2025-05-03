import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awesome_dialog/awesome_dialog.dart'; // Para mejores alertas
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _cargarCredenciales();
  }

  Future<void> _cargarCredenciales() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final password = prefs.getString('password');

    if (email != null && password != null) {
      setState(() {
        _emailController.text = email;
        _passwordController.text = password;
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'Advertencia',
        desc: 'Por favor, completa todos los campos.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // ✅ Guarda email y contraseña si "Recordar sesión" está activado
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', _emailController.text.trim());
        await prefs.setString('password', _passwordController.text);
      }

      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        title: 'Éxito',
        desc: 'Inicio de sesión correcto.',
        btnOkOnPress: () {
          Navigator.pushReplacementNamed(context, '/principal');
        },
      ).show();
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Ocurrió un error';
      if (e.code == 'user-not-found')
        mensaje = 'No se encontró el usuario';
      else if (e.code == 'wrong-password')
        mensaje = 'Contraseña incorrecta';

      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'Error',
        desc: mensaje,
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, size: 100, color: Colors.white),
            const SizedBox(height: 20),

            // Campo de correo
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  icon: Icon(Icons.email, color: Colors.white),
                  hintText: 'Correo electrónico',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Campo de contraseña
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  icon: Icon(Icons.lock, color: Colors.white),
                  hintText: 'Contraseña',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Recordar sesión
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  activeColor: Colors.white,
                  checkColor: Colors.green,
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                ),
                const Text(
                  "Recordar sesión",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),

            // Botón para ir a registro
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/registro');
              },
              child: const Text(
                "¿No tienes cuenta? Regístrate aquí",
                style: TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 10),

            // Botón de login
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.green,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              onPressed: _login,
              child: const Text(
                "Ingresar",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
