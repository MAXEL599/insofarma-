import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'principal.dart';
import 'login.dart';
import 'historial.dart';
import 'ajustes.dart';
import 'manuales.dart';
import 'configuracion_arduino.dart';
import 'registro.dart';
import 'tabla_sensores.dart';

final FlutterLocalNotificationsPlugin notificaciones =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await inicializarNotificaciones();
  runApp(const MyApp());
}

Future<void> inicializarNotificaciones() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
  );

  await notificaciones.initialize(settings);
}

void mostrarNotificacion(String titulo, String cuerpo) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'canal_alertas',
    'Alertas del Invernadero',
    channelDescription: 'Notificaciones críticas del sistema de riego',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails detalles = NotificationDetails(
    android: androidDetails,
  );

  await notificaciones.show(0, titulo, cuerpo, detalles);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/principal': (context) => const PrincipalPage(),
        '/historial': (context) => const HistorialPage(),
        '/ajustes': (context) => const AjustesPage(),
        '/manuales': (context) => const ManualesPage(),
        '/configuracion_arduino': (context) => const ConfiguracionWifiPage(),
        '/registro': (context) => const RegistroPage(),
        '/tabla_sensores': (context) => const TablaSensoresPage(),
      },
    );
  }
}
