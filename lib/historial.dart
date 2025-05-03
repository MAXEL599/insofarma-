import 'package:flutter/material.dart';

class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  // Simulación de datos
  final List<String> configuraciones = [
    "Cambio humedad mínima maceta 1 a 40%",
    "Cambio horario riego a 07:00 AM",
    "Cambio humedad mínima maceta 2 a 35%",
  ];

  final List<String> eventos = [
    "✅ Maceta 1 regada a las 07:01",
    "❌ Maceta 2 no regada - humedad suficiente",
    "✅ Válvula general activada",
    "✅ Maceta 3 regada a las 07:05",
  ];

  void _descargarPDF() {
    // Aquí se implementaría la lógica para generar PDF con los datos locales.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("📄 PDF generado con el historial local")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bool darkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Descargar historial como PDF',
            onPressed: _descargarPDF,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "📋 Historial de Configuraciones",
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ...configuraciones.map(
              (item) => ListTile(
                leading: const Icon(Icons.settings),
                title: Text(item),
              ),
            ),
            const Divider(height: 32),
            Text("🌱 Eventos del Invernadero", style: textTheme.titleMedium),
            const SizedBox(height: 10),
            ...eventos.map(
              (item) => ListTile(
                leading: Icon(
                  item.contains("✅")
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  color: item.contains("✅") ? Colors.green : Colors.orange,
                ),
                title: Text(item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
