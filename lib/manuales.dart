import 'package:flutter/material.dart';

class ManualesPage extends StatelessWidget {
  const ManualesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manuales')),
      body: Center(child: Text('Esta es la pantalla de manuales')),
    );
  }
}
