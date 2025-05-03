// Importaciones necesarias
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ConfiguracionWifiPage extends StatefulWidget {
  const ConfiguracionWifiPage({super.key});

  @override
  State<ConfiguracionWifiPage> createState() => _ConfiguracionWifiPageState();
}

class _ConfiguracionWifiPageState extends State<ConfiguracionWifiPage> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _humedadMinDHT = TextEditingController();
  final TextEditingController _humedadMaxDHT = TextEditingController();
  List<TextEditingController> _humedadesSueloMin = List.generate(
    4,
    (_) => TextEditingController(),
  );
  List<TextEditingController> _humedadesSueloMax = List.generate(
    4,
    (_) => TextEditingController(),
  );
  List<TimeOfDay?> _horarios = List.filled(4, null);
  final FlutterLocalNotificationsPlugin _notifier =
      FlutterLocalNotificationsPlugin();

  bool _arduinoConectado = false;
  bool _configuracionHabilitada = false;
  String _estadoConexion = "Desconectado";
  Color _colorEstado = Colors.red;
  bool _modoManual = false;
  bool _modoEntrePeriodos = false;
  String? _plantaSeleccionada;
  final Map<String, int> _humedadPlantas = {
    'Fresa': 70,
    'Lechuga': 60,
    'Tomate': 65,
    'Pepino': 75,
  };

  @override
  void initState() {
    super.initState();
    _initNotificaciones();
  }

  Future<void> _initNotificaciones() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _notifier.initialize(settings);
  }

  Future<void> _mostrarNotificacion(String titulo, String mensaje) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'canal_alertas',
        'Alertas del sistema',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _notifier.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      titulo,
      mensaje,
      details,
    );
  }

  void _mostrarDialogoConexion() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Conectar con Arduino"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _ssidController,
                  decoration: const InputDecoration(labelText: 'SSID'),
                ),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: _verificarConexion,
                child: const Text("Conectar"),
              ),
            ],
          ),
    );
  }

  Future<void> _verificarConexion() async {
    Navigator.pop(context);
    final url = Uri.parse(
      'http://154.12.246.223:8059/api/arduino/heartbeat/status',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final conectado = jsonDecode(response.body)['conectado'] ?? false;
        setState(() {
          _estadoConexion = conectado ? "🟢 Conectado" : "🔴 Desconectado";
          _colorEstado = conectado ? Colors.green : Colors.red;
          _arduinoConectado = conectado;
          _configuracionHabilitada = conectado;
        });
        if (!conectado) {
          _mostrarNotificacion(
            "Conexión fallida",
            "El Arduino no está disponible",
          );
        }
      } else {
        throw Exception("Código inesperado: ${response.statusCode}");
      }
    } catch (_) {
      setState(() {
        _estadoConexion = "🔴 Desconectado";
        _colorEstado = Colors.red;
        _arduinoConectado = false;
        _configuracionHabilitada = false;
      });
      _mostrarNotificacion("Error de red", "No se pudo contactar al Arduino.");
    }
  }

  Future<void> _enviarConfiguracion() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();
    final humedadMinDHT = int.tryParse(_humedadMinDHT.text) ?? 0;
    final humedadMaxDHT = int.tryParse(_humedadMaxDHT.text) ?? 0;
    final humedadSueloMin =
        _humedadesSueloMin.map((c) => int.tryParse(c.text) ?? 0).toList();
    final humedadSueloMax =
        _humedadesSueloMax.map((c) => int.tryParse(c.text) ?? 0).toList();
    final horarios = _horarios.map((h) => h?.format(context) ?? '').toList();
    final passwordHash = sha256.convert(utf8.encode(password)).toString();

    final config = {
      "ssid": ssid,
      "password": passwordHash,
      "plantaSeleccionada": _plantaSeleccionada ?? "",
      "humedadMinDHT": humedadMinDHT,
      "humedadMaxDHT": humedadMaxDHT,
      "humedadSueloMin": humedadSueloMin,
      "humedadSueloMax": humedadSueloMax,
      "horarios": horarios,
      "modoManual": _modoManual,
      "modoEntrePeriodos": _modoEntrePeriodos,
    };

    final url = Uri.parse('http://154.12.246.223:8059/api/configuracion');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(config),
      );
      if (response.statusCode == 200) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          title: '¡Éxito!',
          desc: 'Configuración enviada correctamente.',
          btnOkOnPress: () {},
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'Error',
          desc: 'Error del servidor: ${response.statusCode}',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'Error de conexión',
        desc: 'No se pudo enviar la configuración: $e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración al Invernadero"),
        actions: [
          TextButton(
            onPressed: _mostrarDialogoConexion,
            child: const Text(
              "Conectarse con el Arduino",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
            const Divider(),
            DropdownButtonFormField<String>(
              value: _plantaSeleccionada,
              hint: const Text("Selecciona una planta"),
              items:
                  _humedadPlantas.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            "${entry.key} (Humedad ideal: ${entry.value}%)",
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  _configuracionHabilitada
                      ? (val) => setState(() => _plantaSeleccionada = val)
                      : null,
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < 4; i++) ...[
              Text(
                "Maceta ${i + 1}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _humedadesSueloMin[i],
                      enabled: _configuracionHabilitada,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Humedad suelo mínima",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _humedadesSueloMax[i],
                      enabled: _configuracionHabilitada,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Humedad suelo máxima",
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text("Hora de riego:"),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed:
                        _configuracionHabilitada
                            ? () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  _horarios[i] = time;
                                });
                              }
                            }
                            : null,
                    child: Text(_horarios[i]?.format(context) ?? "Seleccionar"),
                  ),
                ],
              ),
              const Divider(),
            ],
            TextField(
              controller: _humedadMinDHT,
              keyboardType: TextInputType.number,
              enabled: _configuracionHabilitada,
              decoration: const InputDecoration(
                labelText: "Humedad ambiental mínima (DHT11)",
              ),
            ),
            TextField(
              controller: _humedadMaxDHT,
              keyboardType: TextInputType.number,
              enabled: _configuracionHabilitada,
              decoration: const InputDecoration(
                labelText: "Humedad ambiental máxima (DHT11)",
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _modoManual,
              onChanged:
                  _configuracionHabilitada
                      ? (val) => setState(() => _modoManual = val)
                      : null,
              title: const Text("Modo manual de riego"),
            ),
            SwitchListTile(
              value: _modoEntrePeriodos,
              onChanged:
                  _configuracionHabilitada
                      ? (val) => setState(() => _modoEntrePeriodos = val)
                      : null,
              title: const Text("Modo entre periodos de riego"),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _configuracionHabilitada ? _enviarConfiguracion : null,
                child: const Text("Enviar configuración"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
