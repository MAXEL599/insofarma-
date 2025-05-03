import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AjustesPage extends StatefulWidget {
  const AjustesPage({super.key});

  @override
  State<AjustesPage> createState() => _AjustesPageState();
}

class _AjustesPageState extends State<AjustesPage> {
  bool notificacionesActivas = true;
  String idiomaSeleccionado = 'es';
  List<String> historialCambios = [
    'Se actualizó la humedad mínima para maceta 1',
    'Se desactivó el modo automático',
    'Se conectó el Arduino a nueva red WiFi',
  ];

  @override
  void initState() {
    super.initState();
    cargarPreferencias();
  }

  Future<void> cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificacionesActivas = prefs.getBool('notificaciones') ?? true;
      idiomaSeleccionado = prefs.getString('idioma') ?? 'es';
    });
  }

  Future<void> guardarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificaciones', notificacionesActivas);
    await prefs.setString('idioma', idiomaSeleccionado);
  }

  void cambiarIdioma(String nuevoIdioma) {
    setState(() {
      idiomaSeleccionado = nuevoIdioma;
    });
    guardarPreferencias();
  }

  void cambiarEstadoNotificaciones(bool estado) {
    setState(() {
      notificacionesActivas = estado;
    });
    guardarPreferencias();
  }

  void restablecerConfiguracion() {
    setState(() {
      notificacionesActivas = true;
      idiomaSeleccionado = 'es';
      historialCambios.add('Se restablecieron los ajustes por defecto');
    });
    guardarPreferencias();
  }

  void mostrarDialogoCambioContrasena() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cambiar contraseña'),
            content: const Text(
              'Funcionalidad de cambio de contraseña en desarrollo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  void cerrarSesion() async {
    // Aquí agregar lógica para exportar PDF si se requiere
    final confirmacion = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar cierre de sesión'),
            content: const Text('¿Estás seguro que deseas cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );

    if (confirmacion == true) {
      // lógica para cerrar sesión (FirebaseAuth.instance.signOut(), etc.)
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Widget seccionHistorialCambios() {
    return ExpansionTile(
      title: const Text('Cambios recientes en configuración del Arduino'),
      children:
          historialCambios
              .map((cambio) => ListTile(title: Text(cambio)))
              .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Notificaciones'),
            subtitle: const Text('Activar o desactivar notificaciones'),
            value: notificacionesActivas,
            onChanged: cambiarEstadoNotificaciones,
          ),
          ListTile(
            title: const Text('Idioma'),
            subtitle: Text(idiomaSeleccionado == 'es' ? 'Español' : 'Inglés'),
            trailing: DropdownButton<String>(
              value: idiomaSeleccionado,
              items: const [
                DropdownMenuItem(value: 'es', child: Text('Español')),
                DropdownMenuItem(value: 'en', child: Text('Inglés')),
              ],
              onChanged: (value) {
                if (value != null) cambiarIdioma(value);
              },
            ),
          ),
          ListTile(
            title: const Text('Cambiar contraseña'),
            onTap: mostrarDialogoCambioContrasena,
          ),
          ListTile(
            title: const Text('Información de la aplicación'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Mi Invernadero',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 Insoftech',
              );
            },
          ),
          ListTile(
            title: const Text(
              'Restablecer configuración a valores predeterminados',
            ),
            onTap: restablecerConfiguracion,
          ),
          seccionHistorialCambios(),
          ListTile(title: const Text('Cerrar sesión'), onTap: cerrarSesion),
        ],
      ),
    );
  }
}
