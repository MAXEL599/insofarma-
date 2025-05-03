import 'package:http/http.dart' as http;

class ArduinoService {
  final String baseUrl;

  ArduinoService({required this.baseUrl});

  Future<String> verificarEstadoArduino() async {
    final url = Uri.parse('$baseUrl/api/arduino/status');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return response.body; // 🟢 o 🔴
      } else {
        return '❌ Error: ${response.statusCode}';
      }
    } catch (e) {
      return '❌ Conexión fallida: $e';
    }
  }
}
