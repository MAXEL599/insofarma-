import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<TimeOfDay?> horarios = List.filled(4, null);

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

  void _mostrarDialogoAgregarPlanta() {
    Navigator.pushNamed(context, '/plantasNew');
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

  Future<void> _enviarConfiguracion() async {
    final ssid = ssidController.text.trim();
    final password = passwordController.text.trim();
    final humedadMin = int.tryParse(humedadMinDHT.text) ?? 0;
    final humedadMax = int.tryParse(humedadMaxDHT.text) ?? 0;
    final sueloMin =
        humedadSueloMin.map((c) => int.tryParse(c.text) ?? 0).toList();
    final sueloMax =
        humedadSueloMax.map((c) => int.tryParse(c.text) ?? 0).toList();
    final horariosFormatted =
        horarios.map((h) => h?.format(context) ?? '').toList();
    final passwordHash = sha256.convert(utf8.encode(password)).toString();

    final config = {
      "ssid": ssid,
      "password": passwordHash,
      "humedadMinDHT": humedadMin,
      "humedadMaxDHT": humedadMax,
      "humedadSueloMin": sueloMin,
      "humedadSueloMax": sueloMax,
      "horarios": horariosFormatted,
      "modoManual": _modoManual,
      "modoInteligente": _modoInteligente,
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
          desc: 'Error del servidor: \${response.statusCode}',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'Error de conexión',
        desc: 'No se pudo enviar la configuración: \$e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración al Invernadero'),
        actions: [
          TextButton(
            onPressed: _verificarConexion,
            child: const Text(
              "Conectarse con el Arduino",
              style: TextStyle(color: Colors.white),
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
              "Estado: \$_estadoConexion",
              style: TextStyle(
                color: _colorEstado,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
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
                          _mostrarDialogoAgregarPlanta();
                        } else {
                          setState(() => _plantaSeleccionada = value);
                          _mostrarDialogoSeleccionMacetas(value!);
                        }
                      }
                      : null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: humedadMinDHT,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Humedad ambiental mínima (DHT11)',
              ),
            ),
            TextField(
              controller: humedadMaxDHT,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Humedad ambiental máxima (DHT11)',
              ),
            ),
            const Divider(),
            for (int i = 0; i < 4; i++) ...[
              Text("Maceta \${i + 1}"),
              TextField(
                controller: humedadSueloMin[i],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Humedad suelo mínima',
                ),
              ),
              TextField(
                controller: humedadSueloMax[i],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Humedad suelo máxima',
                ),
              ),
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
                              horarios[i] = time;
                            });
                          }
                        }
                        : null,
                child: Text(horarios[i]?.format(context) ?? 'Hora de riego'),
              ),
              const Divider(),
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
