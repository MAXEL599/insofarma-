import 'dart:async';
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
  bool _guardando = false;

  final List<TextEditingController> humedadMinSuelo = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> humedadMaxSuelo = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final _humedadMinDHT = TextEditingController();
  final _humedadMaxDHT = TextEditingController();
  final _plantaSeleccionada = TextEditingController();

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
  }

  void _abrirHistorialWifi() {
    Navigator.pushNamed(context, '/historialwifi');
  }

  Future<void> _guardarConfiguracionEnFirebase() async {
    setState(() => _guardando = true);

    final db = FirebaseDatabase.instance.ref();
    final ahora = DateTime.now();

    final configFirebase = {
      "fecha": ahora.toIso8601String(),
      "modoManual": true,
      "modoInteligente": false,
      "plantaSeleccionada": _plantaSeleccionada.text,
      "macetas": List.generate(
        4,
        (i) => {
          "min": int.tryParse(humedadMinSuelo[i].text) ?? 0,
          "max": int.tryParse(humedadMaxSuelo[i].text) ?? 0,
          "horarios":
              horarios[i]
                  .map(
                    (h) =>
                        "${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}",
                  )
                  .toList(),
        },
      ),
    };

    final configSpring = {
      "humedadMinDHT": int.tryParse(_humedadMinDHT.text) ?? 0,
      "humedadMaxDHT": int.tryParse(_humedadMaxDHT.text) ?? 100,
      "planta": _plantaSeleccionada.text.trim(),
      "macetas":
          List.generate(4, (i) {
            if (humedadMinSuelo[i].text.isEmpty &&
                humedadMaxSuelo[i].text.isEmpty &&
                horarios[i].isEmpty) {
              return null;
            }
            return {
              "id": i + 1,
              "nombre": "Maceta ${i + 1}",
              "humedadMin": int.tryParse(humedadMinSuelo[i].text) ?? 0,
              "humedadMax": int.tryParse(humedadMaxSuelo[i].text) ?? 100,
              "horarios":
                  horarios[i]
                      .map(
                        (h) =>
                            "${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}",
                      )
                      .toList(),
            };
          }).whereType<Map<String, dynamic>>().toList(),
    };

    try {
      await db.child("configuraciones").push().set(configFirebase);

      final response = await http.post(
        Uri.parse(
          'https://70d5-2806-2f0-2220-f187-c44-a8e5-279c-bc73.ngrok-free.app/api/configuracion',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(configSpring),
      );

      if (response.statusCode == 200) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          title: 'Compilación exitosa',
          desc: 'Configuración guardada en Firebase y enviada al Arduino.',
          btnOkOnPress: () {},
        ).show();
      } else {
        throw Exception('Falló la petición al backend');
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'Error',
        desc: 'No se pudo enviar la configuración.\n$e',
        btnOkOnPress: () {},
      ).show();
    } finally {
      setState(() => _guardando = false);
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
        ...horarios[index].map(
          (h) => Text(
            "Horario: ${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}",
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            if (horarios[index].length >= 4) {
              AwesomeDialog(
                context: context,
                dialogType: DialogType.info,
                title: 'Límite alcanzado',
                desc: 'Solo puedes agregar hasta 4 horarios por maceta.',
                btnOkOnPress: () {},
              ).show();
              return;
            }
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
            onPressed: () async {
              final maceta = index + 1;
              final estado = macetasRegando[index] ? "off" : "on";
              try {
                await http.get(
                  Uri.parse("http://192.168.4.1/rele/$maceta/$estado"),
                );
              } catch (_) {}
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
            onPressed: _guardarConfiguracionEnFirebase,
            tooltip: 'Guardar ahora',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _plantaSeleccionada,
              decoration: const InputDecoration(
                labelText: 'Nombre de la planta',
                prefixIcon: Icon(Icons.local_florist),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _humedadMinDHT,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Humedad mínima (DHT11)',
                prefixIcon: Icon(Icons.thermostat),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _humedadMaxDHT,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Humedad máxima (DHT11)',
                prefixIcon: Icon(Icons.thermostat_auto),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            for (int i = 0; i < 4; i++) _buildMaceta(i),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _guardando ? null : _guardarConfiguracionEnFirebase,
              child:
                  _guardando
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(),
                          ),
                          SizedBox(width: 12),
                          Text("Guardando..."),
                        ],
                      )
                      : const Text(
                        'Guardar configuración en arduino y firebase',
                      ),
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
