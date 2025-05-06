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
    'historial_wifi',
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
          data.entries.map((entry) {
            final v = Map<String, dynamic>.from(entry.value);
            return {
              'id': entry.key,
              'ssid': v['ssid']?.toString() ?? '',
              'password': v['password']?.toString() ?? '',
            };
          }).toList();
      setState(() => _redes = nuevasRedes);
    }
  }

  void _guardarRed() {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();

    if (ssid.isEmpty || password.length < 8) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'Advertencia',
        desc:
            'El SSID no puede estar vacío y la contraseña debe tener al menos 8 caracteres.',
      ).show();
      return;
    }

    final nuevaRed = {'ssid': ssid, 'password': password};
    _wifiRef.push().set(nuevaRed).then((_) {
      _ssidController.clear();
      _passwordController.clear();
      _cargarRedes();
    });
  }

  void _eliminarRed(String id) {
    _wifiRef.child(id).remove().then((_) => _cargarRedes());
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
            ElevatedButton(
              onPressed: _guardarRed,
              child: const Text('Guardar configuración en arduino y firebase'),
            ),
            const Divider(height: 30),
            const Text(
              'Redes guardadas:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _redes.length,
                itemBuilder: (context, index) {
                  final red = _redes[index];
                  return Card(
                    child: ListTile(
                      title: Text(red['ssid'] ?? ''),
                      subtitle: Text('Contraseña: ${red['password'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _eliminarRed(red['id']!),
                      ),
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
