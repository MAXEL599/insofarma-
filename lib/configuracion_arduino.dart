import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';

class ConfiguracionArduinoPage extends StatefulWidget {
  @override
  _ConfiguracionArduinoPageState createState() =>
      _ConfiguracionArduinoPageState();
}

class _ConfiguracionArduinoPageState extends State<ConfiguracionArduinoPage> {
  final FlutterLocalNotificationsPlugin _notifier =
      FlutterLocalNotificationsPlugin();
  bool _arduinoDetectado = false;
  String _estadoConexion = "Desconectado";
  Color _colorEstado = Colors.red;

  final List<TextEditingController> humedadMinSuelo = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> humedadMaxSuelo = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<List<TimeOfDay>> horarios = List.generate(4, (_) => []);

  final List<bool> macetasManualSeleccionadas = List.filled(4, false);
  final List<bool> macetasRegando = List.filled(4, false);

  @override
  void initState() {
    super.initState();
    final settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    _notifier.initialize(settings);
    _verificarConexion();
  }

  Future<void> _verificarConexion() async {
    final url = Uri.parse('https://154.12.246.223:8443/api/arduino/conectado');
    try {
      final response = await http.get(url);
      final conectado =
          response.statusCode == 200 && response.body.contains("conectado");
      if (!mounted) return;

      setState(() {
        _estadoConexion = conectado ? "🟢 Conectado" : "🔴 Desconectado";
        _colorEstado = conectado ? Colors.green : Colors.red;
        _arduinoDetectado = conectado;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estadoConexion = "🔴 Desconectado";
        _colorEstado = Colors.red;
        _arduinoDetectado = false;
      });
    }
  }

  void _abrirHistorialWifi() {
    Navigator.pushNamed(context, '/historialwifi');
  }

  Future<void> _guardarConfiguracionEnFirebase() async {
    if (!_arduinoDetectado) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'Arduino no conectado',
        desc:
            'No se puede guardar la configuración porque el Arduino no está conectado.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final db = FirebaseDatabase.instance.ref();
    final ahora = DateTime.now();
    final config = {
      "fecha": ahora.toIso8601String(),
      "modoManual": true,
      "modoInteligente": false,
      "macetas": List.generate(
        4,
        (i) => {
          "min": int.tryParse(humedadMinSuelo[i].text) ?? 0,
          "max": int.tryParse(humedadMaxSuelo[i].text) ?? 0,
          "horarios": horarios[i].map((h) => h.format(context)).toList(),
        },
      ),
    };

    try {
      await db.child("configuraciones").push().set(config);
      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        title: 'Éxito',
        desc: 'Configuración guardada en Firebase.',
        btnOkOnPress: () {},
      ).show();
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'Error',
        desc: 'No se pudo guardar la configuración.',
        btnOkOnPress: () {},
      ).show();
    }
  }

  Widget _buildMaceta(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Maceta ${index + 1}"),
        TextField(
          controller: humedadMinSuelo[index],
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Humedad suelo mínima',
            prefixIcon: Icon(Icons.water_drop_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: humedadMaxSuelo[index],
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Humedad suelo máxima',
            prefixIcon: Icon(Icons.opacity),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ...horarios[index].map((h) => Text("Horario: ${h.format(context)}")),
        ElevatedButton.icon(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              setState(() {
                horarios[index].add(picked);
              });
            }
          },
          icon: const Icon(Icons.access_time),
          label: const Text("Agregar horario"),
        ),
        CheckboxListTile(
          value: macetasManualSeleccionadas[index],
          onChanged:
              (val) => setState(
                () => macetasManualSeleccionadas[index] = val ?? false,
              ),
          title: const Text("Seleccionar para riego manual"),
        ),
        if (macetasManualSeleccionadas[index])
          ElevatedButton(
            onPressed: () {
              setState(() {
                macetasRegando[index] = !macetasRegando[index];
              });
            },
            child: Text(
              macetasRegando[index] ? "Detener riego" : "Iniciar riego",
            ),
          ),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración del Riego'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _verificarConexion,
            tooltip: 'Refrescar estado',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Estado: $_estadoConexion",
              style: TextStyle(
                color: _colorEstado,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            for (int i = 0; i < 4; i++) _buildMaceta(i),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _guardarConfiguracionEnFirebase,
              child: const Text('Guardar configuración en arduino y firebase'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _abrirHistorialWifi,
              child: const Text('Agregar o cambiar red WiFi'),
            ),
          ],
        ),
      ),
    );
  }
}
