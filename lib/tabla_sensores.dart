import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TablaSensoresPage extends StatefulWidget {
  const TablaSensoresPage({super.key});

  @override
  State<TablaSensoresPage> createState() => _TablaSensoresPageState();
}

class _TablaSensoresPageState extends State<TablaSensoresPage> {
  final _yl69Ref = FirebaseDatabase.instance.ref('yl69');
  final _dht11Ref = FirebaseDatabase.instance.ref('dht11');
  final _relesRef = FirebaseDatabase.instance.ref('reles');

  List<Map> _lecturas = [];
  String _filtroFecha = '';
  String _filtroHumedad = 'todos';

  @override
  void initState() {
    super.initState();
    _escucharDatos();
  }

  void _escucharDatos() async {
    final ylSnapshot = await _yl69Ref.get();
    final dhtSnapshot = await _dht11Ref.get();
    final releSnapshot = await _relesRef.get();

    final List<Map> nuevaLista = [];

    if (ylSnapshot.exists && ylSnapshot.value is Map) {
      final ylData = Map<String, dynamic>.from(ylSnapshot.value as Map);

      ylData.forEach((key, yl) {
        final humedadSuelo = yl['humedad'] ?? '-';
        final maceta = yl['maceta'] ?? '-';
        final fechaHoraYL = yl['fechaHora'] ?? '-';

        String humedadAmbiente = '-';
        String temperatura = '-';
        if (dhtSnapshot.exists && dhtSnapshot.value is Map) {
          final dhtData = Map<String, dynamic>.from(dhtSnapshot.value as Map);
          final first = dhtData.values.first;
          humedadAmbiente = first['humedad'] ?? '-';
          temperatura = first['temperatura'] ?? '-';
        }

        String riego = 'no';
        if (releSnapshot.exists && releSnapshot.value is Map) {
          final relData = Map<String, dynamic>.from(releSnapshot.value as Map);
          final match = relData.values.firstWhere(
            (rele) => rele['rele'].toString() == maceta.toString(),
            orElse: () => {},
          );
          if (match is Map && match['encendido'] == true) {
            riego = 'sí';
          }
        }

        final partes = (fechaHoraYL as String).split(' ');
        final fecha = partes.isNotEmpty ? partes[0] : '-';
        final hora = partes.length > 1 ? partes[1] : '-';

        nuevaLista.add({
          'maceta': maceta,
          'humedad': humedadSuelo,
          'temperatura': temperatura,
          'riego': riego,
          'fecha': fecha,
          'hora': hora,
        });
      });

      nuevaLista.sort((a, b) {
        final fechaA = '${a['fecha']} ${a['hora']}';
        final fechaB = '${b['fecha']} ${b['hora']}';
        return fechaB.compareTo(fechaA);
      });
    }

    setState(() {
      _lecturas = nuevaLista;
    });
  }

  List<Map> get _lecturasFiltradas {
    return _lecturas.where((lectura) {
      final cumpleFecha =
          _filtroFecha.isEmpty || lectura['fecha'] == _filtroFecha;

      final humedad =
          int.tryParse(
            lectura['humedad'].toString().replaceAll('%', '').trim(),
          ) ??
          0;
      final cumpleHumedad =
          _filtroHumedad == 'todos' ||
          (_filtroHumedad == 'alta' && humedad >= 60) ||
          (_filtroHumedad == 'baja' && humedad < 60);

      return cumpleFecha && cumpleHumedad;
    }).toList();
  }

  void _seleccionarFecha() async {
    final DateTime? seleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (seleccionada != null) {
      setState(() {
        _filtroFecha = DateFormat('yyyy-MM-dd').format(seleccionada);
      });
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroFecha = '';
      _filtroHumedad = 'todos';
    });
  }

  Future<void> _exportarCSV() async {
    final List<List<String>> csvData = [
      ['Maceta', 'Humedad', 'Temperatura', 'Riego', 'Fecha', 'Hora'],
      ..._lecturasFiltradas.map(
        (e) => [
          e['maceta'].toString(),
          e['humedad'].toString(),
          e['temperatura'].toString(),
          e['riego'].toString(),
          e['fecha'].toString(),
          e['hora'].toString(),
        ],
      ),
    ];

    final String csv = const ListToCsvConverter().convert(csvData);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/lecturas.csv');
    await file.writeAsString(csv);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV exportado correctamente.')),
    );
  }

  Future<void> _exportarPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build:
            (context) => pw.Table.fromTextArray(
              headers: [
                'Maceta',
                'Humedad',
                'Temperatura',
                'Riego',
                'Fecha',
                'Hora',
              ],
              data:
                  _lecturasFiltradas
                      .map(
                        (e) => [
                          e['maceta'],
                          e['humedad'],
                          e['temperatura'],
                          e['riego'],
                          e['fecha'],
                          e['hora'],
                        ],
                      )
                      .toList(),
            ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DataTableSource source = _SensorDataSource(_lecturasFiltradas);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabla de Sensores'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportarCSV,
            tooltip: 'Exportar CSV',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportarPDF,
            tooltip: 'Exportar PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _escucharDatos();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Datos actualizados desde Firebase.'),
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(label: 'Cerrar', onPressed: () {}),
                ),
              );
            },
            tooltip: 'Recargar datos',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _seleccionarFecha,
                        icon: const Icon(Icons.search),
                        label: Text(
                          _filtroFecha.isEmpty
                              ? 'Búsqueda por filtros'
                              : 'Fecha: $_filtroFecha',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _filtroHumedad,
                        items: const [
                          DropdownMenuItem(
                            value: 'todos',
                            child: Text('Todas las humedades'),
                          ),
                          DropdownMenuItem(
                            value: 'alta',
                            child: Text('Humedad alta (≥ 60%)'),
                          ),
                          DropdownMenuItem(
                            value: 'baja',
                            child: Text('Humedad baja (< 60%)'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filtroHumedad = value!;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _limpiarFiltros,
                    icon: const Icon(Icons.clear),
                    label: const Text('Quitar filtros'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PaginatedDataTable(
                header: const Text('Lecturas registradas'),
                rowsPerPage: 5,
                columns: const [
                  DataColumn(label: Text('Maceta')),
                  DataColumn(label: Text('Humedad')),
                  DataColumn(label: Text('Temperatura')),
                  DataColumn(label: Text('Riego')),
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Hora')),
                ],
                source: source,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorDataSource extends DataTableSource {
  final List<Map> data;
  _SensorDataSource(this.data);

  @override
  DataRow getRow(int index) {
    final row = data[index];
    return DataRow(
      cells: [
        DataCell(Text(row['maceta'].toString())),
        DataCell(Text(row['humedad'].toString())),
        DataCell(Text(row['temperatura'].toString())),
        DataCell(
          Row(
            children: [
              Icon(
                row['riego'] == 'sí' ? Icons.check_circle : Icons.cancel,
                color: row['riego'] == 'sí' ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(row['riego'].toString()),
            ],
          ),
        ),
        DataCell(Text(row['fecha'].toString())),
        DataCell(Text(row['hora'].toString())),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => data.length;
  @override
  int get selectedRowCount => 0;
}
