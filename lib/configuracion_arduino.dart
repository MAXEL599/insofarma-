import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';

class ConfiguracionArduinoPage extends StatefulWidget {
  @override
  _ConfiguracionArduinoPageState createState() =>
      _ConfiguracionArduinoPageState();
}

class _ConfiguracionArduinoPageState extends State<ConfiguracionArduinoPage> {
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController humedadMinDHT = TextEditingController();
  final TextEditingController humedadMaxDHT = TextEditingController();
  final List<TextEditingController> humedadSueloMin = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> humedadSueloMax = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<List<TimeOfDay>> horarios = List.generate(4, (_) => []);
  final List<String?> _plantasPorMaceta = List.filled(4, null);

  final FlutterLocalNotificationsPlugin _notifier =
      FlutterLocalNotificationsPlugin();

  bool _arduinoConectado = false;
  bool _configuracionHabilitada = false;
  bool _editable = false;
  String _estadoConexion = "Desconectado";
  Color _colorEstado = Colors.red;
  bool _modoManual = false;
  bool _modoInteligente = false;

  String? _plantaSeleccionada;
  List<String> _plantasDisponibles = [
    'Fresa',
    'Lechuga',
    'Tomate',
    'Pepino',
    'Frijol',
    'Agregar nueva...',
  ];
  final List<bool> _macetasSeleccionManual = List.filled(4, false);
  final List<bool> _macetasRegando = List.filled(4, false);

  @override
  void initState() {
    super.initState();
    _cargarPlantasFirebase();
    _cargarWifiGuardado();
    _verificarConexion();
  }

  Future<void> _cargarPlantasFirebase() async {
    final db = FirebaseDatabase.instance.ref();
    final snapshot = await db.child('plantas').once();
    final data = snapshot.snapshot.value;
    if (data != null && data is Map && mounted) {
      setState(() {
        _plantasDisponibles = [...data.keys.cast<String>(), 'Agregar nueva...'];
      });
    }
  }

  Future<void> _guardarWifiLocal(String ssid, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wifi_ssid', ssid);
    await prefs.setString('wifi_password', password);
  }

  Future<void> _cargarWifiGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final ssid = prefs.getString('wifi_ssid');
    final password = prefs.getString('wifi_password');

    if (ssid != null && password != null && mounted) {
      ssidController.text = ssid;
      passwordController.text = password;
      setState(() {
        _configuracionHabilitada = true;
        _editable = true;
      });
    }
  }

  Future<void> _verificarConexion() async {
    final url = Uri.parse(
      'http://154.12.246.223:8059/api/arduino/heartbeat/status',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final conectado = jsonDecode(response.body)['conectado'] ?? false;
        if (mounted) {
          setState(() {
            _estadoConexion = conectado ? "🟢 Conectado" : "🔴 Desconectado";
            _colorEstado = conectado ? Colors.green : Colors.red;
            _arduinoConectado = conectado;
            _configuracionHabilitada = conectado;
            _editable = conectado;
          });
        }
      } else {
        throw Exception("Código inesperado: \${response.statusCode}");
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _estadoConexion = "🔴 Desconectado";
          _colorEstado = Colors.red;
          _arduinoConectado = false;
          _configuracionHabilitada = false;
          _editable = false;
        });
      }
    }
  }

  void _mostrarDialogoWifi() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Conexión WiFi del Arduino"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ssidController,
                  onChanged: (_) => setState(() => _editable = false),
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la red WiFi (SSID)',
                    prefixIcon: Icon(Icons.wifi),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  onChanged: (_) => setState(() => _editable = false),
                  decoration: const InputDecoration(
                    labelText: 'Contraseña WiFi',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cerrar"),
              ),
            ],
          ),
    );
  }

  void _guardarConfiguracionEnFirebase() async {
    final db = FirebaseDatabase.instance.ref();
    final now = DateTime.now().toLocal().toString();
    final horariosFlat =
        horarios.expand((e) => e).map((h) => h.format(context)).toList();

    await db.child('configuraciones').push().set({
      'fecha': now,
      'ssid': ssidController.text,
      'password': passwordController.text,
      'plantasSeleccionadas': _plantasPorMaceta,
      'humedadMinDHT': int.tryParse(humedadMinDHT.text) ?? 0,
      'humedadMaxDHT': int.tryParse(humedadMaxDHT.text) ?? 0,
      'humedadesMacetas': List.generate(
        4,
        (i) => int.tryParse(humedadSueloMin[i].text) ?? 0,
      ),
      'modoManual': _modoManual,
      'modoEntrePeriodos': _modoInteligente,
      'horarios': horariosFlat,
    });
  }

  Widget _buildMacetaFields(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Maceta ${index + 1}"),
        TextField(
          controller: humedadSueloMin[index],
          decoration: InputDecoration(
            labelText: 'Humedad suelo mínima',
            prefixIcon: Icon(Icons.water_drop_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: humedadSueloMax[index],
          decoration: InputDecoration(
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
          icon: Icon(Icons.access_time),
          label: Text("Agregar horario"),
        ),
        if (_modoManual) ...[
          CheckboxListTile(
            value: _macetasSeleccionManual[index],
            onChanged:
                (val) => setState(
                  () => _macetasSeleccionManual[index] = val ?? false,
                ),
            title: Text("Seleccionar para riego manual"),
          ),
          if (_macetasSeleccionManual[index])
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _macetasRegando[index] = !_macetasRegando[index];
                });
              },
              child: Text(
                _macetasRegando[index] ? "Detener riego" : "Iniciar riego",
              ),
            ),
        ],
        Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración al Invernadero'),
        backgroundColor: Colors.green,
        actions: [
          TextButton(
            onPressed: _mostrarDialogoWifi,
            child: Text(
              "Conectarse con el Arduino",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade100, Colors.lightBlue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _plantaSeleccionada,
                hint: const Text("Selecciona una planta"),
                items:
                    _plantasDisponibles
                        .map(
                          (planta) => DropdownMenuItem(
                            value: planta,
                            child: Text(planta),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value == 'Agregar nueva...') {
                    Navigator.pushNamed(context, '/plantasnew');
                  } else {
                    setState(() => _plantaSeleccionada = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: humedadMinDHT,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Humedad ambiental mínima (DHT11)',
                  prefixIcon: Icon(Icons.water_drop),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: humedadMaxDHT,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Humedad ambiental máxima (DHT11)',
                  prefixIcon: Icon(Icons.opacity),
                  border: OutlineInputBorder(),
                ),
              ),
              const Divider(),
              for (int i = 0; i < 4; i++) _buildMacetaFields(i),
              SwitchListTile(
                value: _modoManual,
                onChanged: (val) => setState(() => _modoManual = val),
                title: const Text("Modo manual de riego"),
              ),
              SwitchListTile(
                value: _modoInteligente,
                onChanged:
                    _configuracionHabilitada
                        ? (val) => setState(() => _modoInteligente = val)
                        : null,
                title: const Text("Modo inteligente de riego"),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _configuracionHabilitada ? () {} : null,
                  child: const Text("Enviar configuración"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
