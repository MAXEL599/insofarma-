import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  // Controladores de texto para los campos del formulario
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  String? _celular;
  String? _rolSeleccionado;

  // Lista de roles disponibles
  final List<String> _roles = ['Dueño', 'Desarrollador', 'Agrónomo'];

  // Función que valida y registra al usuario
  void _validarRegistro() async {
    String nombre = _nombreController.text.trim();
    String correo = _correoController.text.trim();
    String contrasena = _contrasenaController.text;

    // Validación de campos vacíos
    if (nombre.isEmpty ||
        correo.isEmpty ||
        contrasena.isEmpty ||
        _celular == null ||
        _rolSeleccionado == null) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'Advertencia',
        desc: 'Por favor, completa todos los campos.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    // Validación de correo electrónico
    if (!correo.contains('@') || !correo.contains('.')) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'Correo inválido',
        desc: 'El correo debe contener @ y dominio.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    // Validación de contraseña (mínimo 8 dígitos numéricos)
    if (contrasena.length < 8 || !RegExp(r'^[0-9]+$').hasMatch(contrasena)) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'Contraseña inválida',
        desc: 'La contraseña debe ser numérica y de al menos 8 dígitos.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    try {
      // Registro con Firebase Auth
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: correo, password: contrasena);

      // Guardar información adicional en Firebase Realtime Database
      final database = FirebaseDatabase.instance;
      final ref = database.ref("usuarios/${cred.user!.uid}");

      await ref.set({
        "nombre": nombre,
        "rol": _rolSeleccionado,
        "celular": _celular,
        "correo": correo,
      });

      // Mensaje de éxito
      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        title: 'Registro Exitoso',
        desc: '¡Bienvenido, $nombre!',
        btnOkOnPress: () {
          Navigator.pushReplacementNamed(context, '/principal');
        },
      ).show();
    } on FirebaseAuthException catch (e) {
      // Error en el registro
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'Error de registro',
        desc: e.message ?? 'Ocurrió un error al registrar.',
        btnOkOnPress: () {},
      ).show();
    }
  }

  // Método reutilizable para los campos de texto
  Widget campoTexto(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: BorderRadius.circular(30),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          icon: Icon(
            isPassword ? Icons.lock : Icons.person,
            color: Colors.white,
          ),
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // Interfaz de usuario
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Icon(
                Icons.app_registration,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 20),

              // Campos de entrada
              campoTexto('Nombre completo', _nombreController),
              campoTexto(
                'Correo electrónico',
                _correoController,
                inputType: TextInputType.emailAddress,
              ),
              campoTexto(
                'Contraseña (solo números)',
                _contrasenaController,
                isPassword: true,
                inputType: TextInputType.number,
              ),

              // Campo de celular con selección de país
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(30),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: IntlPhoneField(
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    hintText: 'Número de celular',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                    icon: Icon(Icons.phone, color: Colors.white, size: 20),
                  ),
                  initialCountryCode: 'MX',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  dropdownTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  dropdownIcon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                    size: 20,
                  ),
                  onChanged: (phone) {
                    _celular = phone.completeNumber;
                  },
                ),
              ),

              // Menú desplegable para rol
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(30),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: Colors.green.shade700,
                    hint: const Text(
                      'Selecciona tu rol',
                      style: TextStyle(color: Colors.white70),
                    ),
                    value: _rolSeleccionado,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                    ),
                    items:
                        _roles.map((rol) {
                          return DropdownMenuItem<String>(
                            value: rol,
                            child: Text(
                              rol,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _rolSeleccionado = value;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botón de registro
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
                onPressed: _validarRegistro,
                child: const Text(
                  "Registrarse",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              // Botones de registro social (a implementar)
              const Text(
                'O registrarse con:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.g_mobiledata,
                      size: 40,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.code, size: 30, color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.facebook,
                      size: 30,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
