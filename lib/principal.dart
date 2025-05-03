import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class PrincipalPage extends StatefulWidget {
  const PrincipalPage({super.key});

  @override
  State<PrincipalPage> createState() => _PrincipalPageState();
}

class _PrincipalPageState extends State<PrincipalPage> {
  String _ubicacion = 'Cargando...';
  String _temperatura = '...';
  String _sensacionTermica = '...';
  String _humedad = '...';
  String _viento = '...';

  String _nombre = '';
  String _correo = '';
  String _rol = '';

  bool _modoOscuro = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _obtenerUsuarioActual();
    _obtenerUbicacionYClima();
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _obtenerUbicacionYClima();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _obtenerUsuarioActual() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseDatabase.instance.ref('usuarios/${user.uid}');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _nombre = data['nombre'] ?? '';
          _correo = data['correo'] ?? '';
          _rol = data['rol'] ?? '';
        });
      }
    }
  }

  Future<void> _obtenerUbicacionYClima() async {
    bool permiso = await Geolocator.isLocationServiceEnabled();
    if (!permiso) {
      setState(() => _ubicacion = 'GPS desactivado');
      return;
    }

    LocationPermission permisoGps = await Geolocator.checkPermission();
    if (permisoGps == LocationPermission.denied) {
      permisoGps = await Geolocator.requestPermission();
      if (permisoGps == LocationPermission.denied) {
        setState(() => _ubicacion = 'Permiso denegado');
        return;
      }
    }

    final posicion = await Geolocator.getCurrentPosition();
    final placemarks = await placemarkFromCoordinates(
      posicion.latitude,
      posicion.longitude,
    );
    final ciudad = placemarks[0].locality ?? placemarks[0].administrativeArea;
    setState(() {
      _ubicacion = ciudad ?? 'Desconocido';
    });

    final url =
        "https://api.open-meteo.com/v1/forecast?latitude=${posicion.latitude}&longitude=${posicion.longitude}&current_weather=true&hourly=relative_humidity_2m,apparent_temperature";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        final weather = data['current_weather'];

        final humedadLista = data['hourly']['relative_humidity_2m'];
        final humedadValor =
            (humedadLista != null && humedadLista.isNotEmpty)
                ? '${humedadLista[0]}%'
                : 'No disponible';

        setState(() {
          _temperatura =
              weather['temperature'] != null
                  ? '${weather['temperature']}°C'
                  : 'No disponible';

          _sensacionTermica =
              weather['apparent_temperature'] != null
                  ? '${weather['apparent_temperature']}°C'
                  : 'No disponible';

          _viento =
              weather['windspeed'] != null
                  ? '${weather['windspeed']} km/h'
                  : 'No disponible';

          _humedad = humedadValor;
        });
      } catch (e) {
        print("❌ Error al parsear los datos del clima: $e");
      }
    } else {
      print("❌ Error al obtener clima: Código ${response.statusCode}");
    }
  }

  void _cerrarSesion() {
    final TextEditingController _passController = TextEditingController();
    AwesomeDialog(
      context: context,
      dialogType: DialogType.question,
      title: 'Cerrar Sesión',
      body: Column(
        children: [
          Text(
            'Ingresa tu contraseña para cerrar sesión:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
        ],
      ),
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        try {
          User? user = FirebaseAuth.instance.currentUser;
          final cred = EmailAuthProvider.credential(
            email: user!.email!,
            password: _passController.text,
          );
          await user.reauthenticateWithCredential(cred);
          await FirebaseAuth.instance.signOut();
          Navigator.pushReplacementNamed(context, '/');
        } catch (_) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'Error',
            desc: 'Contraseña incorrecta.',
            btnOkOnPress: () {},
          ).show();
        }
      },
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: _modoOscuro ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text('Panel Principal', style: textTheme.titleLarge),
        backgroundColor: _modoOscuro ? Colors.grey[900] : Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: () {
              setState(() {
                _modoOscuro = !_modoOscuro;
              });
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: _modoOscuro ? Colors.grey[900] : Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nombre,
                    style: textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _correo,
                    style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rol: $_rol',
                    style: textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.settings,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text('Ajustes', style: textTheme.bodyMedium),
              onTap: () => Navigator.pushNamed(context, '/ajustes'),
            ),
            ListTile(
              leading: Icon(
                Icons.menu_book,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text('Manuales', style: textTheme.bodyMedium),
              onTap: () => Navigator.pushNamed(context, '/manuales'),
            ),
            ListTile(
              leading: Icon(
                Icons.history,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text('Historial', style: textTheme.bodyMedium),
              onTap: () => Navigator.pushNamed(context, '/historial'),
            ),
            ListTile(
              leading: Icon(
                Icons.table_chart,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text('Tabla de sensores', style: textTheme.bodyMedium),
              onTap: () => Navigator.pushNamed(context, '/tabla_sensores'),
            ),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text('Cerrar Sesión', style: textTheme.bodyMedium),
              onTap: _cerrarSesion,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: _modoOscuro ? Colors.grey[850] : Colors.green.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del clima',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _modoOscuro ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _infoClima('Ubicación', _ubicacion),
                    _infoClima('Temperatura', _temperatura),
                    _infoClima('Sensación térmica', _sensacionTermica),
                    _infoClima('Humedad', _humedad),
                    _infoClima('Viento', _viento),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/configuracion_arduino');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _modoOscuro ? Colors.grey[700] : Colors.green,
                foregroundColor: _modoOscuro ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: Icon(
                Icons.memory,
                color: _modoOscuro ? Colors.white : Colors.black,
              ),
              label: Text(
                "Acceder Arduino",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _modoOscuro ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoClima(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$titulo: $valor',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _modoOscuro ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }
}
