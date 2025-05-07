import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class HistorialWifiPage extends StatefulWidget {
  const HistorialWifiPage({Key? key}) : super(key: key);

  @override
  State<HistorialWifiPage> createState() => _HistorialWifiPageState();
}

class _HistorialWifiPageState extends State<HistorialWifiPage> {
  final DatabaseReference _wifiRef = FirebaseDatabase.instance.ref().child(
    'configuracionWifi',
  );

  List<Map<String, String>> _redes = [];
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarRedes();
  }

  void _cargarRedes() async {
    final snapshot = await _wifiRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final nuevasRedes =
          data.entries.where((entry) => entry.value is Map).map((entry) {
            final v = Map<String, dynamic>.from(entry.value as Map);
            return {
              'id': entry.key,
              'ssid': v['SSID']?.toString() ?? '',
              'password': v['password']?.toString() ?? '',
            };
          }).toList();

      setState(() => _redes = nuevasRedes);
    } else {
      setState(() => _redes = []);
    }
  }

  void _guardarRed() {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();

    if (ssid.isEmpty || password.length < 8) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'Datos inválidos',
        desc:
            'El SSID no puede estar vacío y la contraseña debe tener al menos 8 caracteres.',
      ).show();
      return;
    }

    final nuevaRed = {'SSID': ssid, 'password': password};
    _wifiRef.push().set(nuevaRed).then((_) {
      _ssidController.clear();
      _passwordController.clear();
      _cargarRedes();
    });
  }

  void _conectarRed(String ssid, String password) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      title: 'Conectando...',
      desc: 'Conectando a la red $ssid',
      btnOkOnPress: () {
        print('✅ Conectado a $ssid con contraseña $password');
        // Aquí iría la llamada a Spring Boot con HTTP POST si lo deseas implementar
      },
    ).show();
  }

  void _eliminarRed(String id) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      title: '¿Estás seguro?',
      desc: '¿Deseas eliminar esta red WiFi?',
      btnCancelText: "No",
      btnOkText: "Sí",
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        _wifiRef.child(id).remove().then((_) => _cargarRedes());
      },
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de redes WiFi')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: 'Nombre de red (SSID)',
                prefixIcon: Icon(Icons.wifi),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar red'),
                    onPressed: _guardarRed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.wifi),
                    label: const Text('Conectar red'),
                    onPressed: () {
                      final ssid = _ssidController.text.trim();
                      final password = _passwordController.text.trim();
                      if (ssid.isNotEmpty && password.length >= 8) {
                        _conectarRed(ssid, password);
                      } else {
                        AwesomeDialog(
                          context: context,
                          dialogType: DialogType.warning,
                          title: 'Datos inválidos',
                          desc:
                              'Debes ingresar SSID y contraseña válida (mín. 8 caracteres).',
                        ).show();
                      }
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            const Text(
              'Redes guardadas:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child:
                  _redes.isEmpty
                      ? const Center(child: Text("No hay redes guardadas"))
                      : ListView.builder(
                        itemCount: _redes.length,
                        itemBuilder: (context, index) {
                          final red = _redes[index];
                          return Card(
                            child: ListTile(
                              title: Text(red['ssid'] ?? ''),
                              subtitle: Text(
                                'Contraseña: ${red['password'] ?? ''}',
                              ),
                              onTap:
                                  () => _conectarRed(
                                    red['ssid']!,
                                    red['password']!,
                                  ),
                              onLongPress: () => _eliminarRed(red['id']!),
                              trailing: const Icon(Icons.touch_app),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
