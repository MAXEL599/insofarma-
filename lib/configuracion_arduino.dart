import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

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

  final FlutterLocalNotificationsPlugin _notifier =
      FlutterLocalNotificationsPlugin();

  bool _arduinoConectado = false;
  bool _configuracionHabilitada = false;
  String _estadoConexion = "Desconectado";
  Color _colorEstado = Colors.red;
  bool _modoManual = false;
  bool _modoInteligente = false;

  String? _plantaSeleccionada;
  final List<String> _plantasDisponibles = [
    'Fresa',
    'Lechuga',
    'Tomate',
    'Pepino',
    'Frijol',
    'Agregar nueva...',
  ];
  final List<bool> _macetasSeleccionManual = List.filled(4, false);

  @override
  void initState() {
    super.initState();
    _verificarConexion();
  }

  Future<void> _verificarConexion() async {
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
        throw Exception("Código inesperado: \${response.statusCode}");
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

  void _asignarHumedadPorPlanta(String planta, List<int> macetasSeleccionadas) {
    final humedadPorPlanta = {
      'Fresa': [60, 80],
      'Lechuga': [50, 70],
      'Tomate': [65, 85],
      'Pepino': [70, 90],
      'Frijol': [55, 75],
    };

    final valores = humedadPorPlanta[planta];
    if (valores != null) {
      for (var i in macetasSeleccionadas) {
        humedadSueloMin[i].text = valores[0].toString();
        humedadSueloMax[i].text = valores[1].toString();
      }
    }
  }

  void _mostrarDialogoSeleccionMacetas(String planta) {
    showDialog(
      context: context,
      builder: (context) {
        List<bool> seleccion = List.filled(5, false);
        return AlertDialog(
          title: Text("¿Dónde quieres plantar \$planta?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 4; i++)
                StatefulBuilder(
                  builder:
                      (context, setStateDialog) => CheckboxListTile(
                        value: seleccion[i],
                        onChanged:
                            (val) => setStateDialog(() => seleccion[i] = val!),
                        title: Text("Maceta \${i + 1}"),
                      ),
                ),
              StatefulBuilder(
                builder:
                    (context, setStateDialog) => CheckboxListTile(
                      value: seleccion[4],
                      onChanged:
                          (val) => setStateDialog(() => seleccion[4] = val!),
                      title: Text("Todas las macetas"),
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                List<int> seleccionadas = [];
                if (seleccion[4]) {
                  seleccionadas = [0, 1, 2, 3];
                } else {
                  for (int i = 0; i < 4; i++) {
                    if (seleccion[i]) seleccionadas.add(i);
                  }
                }
                _asignarHumedadPorPlanta(planta, seleccionadas);
                Navigator.pop(context);
              },
              child: Text("Aceptar"),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoModificarHorarios(int macetaIndex) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Modificar horarios - Maceta \${macetaIndex + 1}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...horarios[macetaIndex].asMap().entries.map((entry) {
                  int index = entry.key;
                  TimeOfDay hora = entry.value;
                  return ListTile(
                    title: Text(hora.format(context)),
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () async {
                        final nuevaHora = await showTimePicker(
                          context: context,
                          initialTime: hora,
                        );
                        if (nuevaHora != null) {
                          setState(() {
                            horarios[macetaIndex][index] = nuevaHora;
                          });
                          Navigator.pop(context);
                          _mostrarDialogoModificarHorarios(macetaIndex);
                        }
                      },
                    ),
                  );
                }).toList(),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cerrar"),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración al Invernadero'),
        backgroundColor: Colors.green,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade100, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Estado: \$_estadoConexion",
                style: TextStyle(
                  color: _colorEstado,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ssidController,
                enabled: _configuracionHabilitada,
                decoration: InputDecoration(
                  labelText: 'Nombre de la red WiFi (SSID)',
                  prefixIcon: Icon(Icons.wifi),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                enabled: _configuracionHabilitada,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña WiFi',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
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
                onChanged:
                    _configuracionHabilitada
                        ? (value) {
                          if (value == 'Agregar nueva...') {
                            Navigator.pushNamed(context, '/plantasNew');
                          } else {
                            setState(() => _plantaSeleccionada = value);
                            _mostrarDialogoSeleccionMacetas(value!);
                          }
                        }
                        : null,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: humedadMinDHT,
                keyboardType: TextInputType.number,
                enabled: _configuracionHabilitada,
                decoration: const InputDecoration(
                  labelText: 'Humedad ambiental mínima (DHT11)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: humedadMaxDHT,
                keyboardType: TextInputType.number,
                enabled: _configuracionHabilitada,
                decoration: const InputDecoration(
                  labelText: 'Humedad ambiental máxima (DHT11)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop),
                ),
              ),
              const SizedBox(height: 20),
              for (int i = 0; i < 4; i++) ...[
                Text(
                  "Maceta \${i + 1}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: humedadSueloMin[i],
                  enabled: _configuracionHabilitada,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Humedad suelo mínima',
                    prefixIcon: Icon(Icons.water_drop_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: humedadSueloMax[i],
                  enabled: _configuracionHabilitada,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Humedad suelo máxima',
                    prefixIcon: Icon(Icons.water_drop),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          _configuracionHabilitada
                              ? () => _mostrarDialogoModificarHorarios(i)
                              : null,
                      icon: Icon(Icons.access_time),
                      label: Text('Modificar horarios'),
                    ),
                  ],
                ),
                Divider(),
              ],
              SwitchListTile(
                value: _modoManual,
                onChanged:
                    _configuracionHabilitada
                        ? (val) => setState(() => _modoManual = val)
                        : null,
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
              const SizedBox(height: 20),
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
