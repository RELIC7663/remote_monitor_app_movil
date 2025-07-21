import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:remote_monitor_app_movil/data/databaseHelper.dart'; // Asegúrate de que la ruta sea correcta
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io'; // Para Platform.isWindows, Platform.isAndroid, etc.

void main() {
  // Asegura que los bindings de Flutter estén inicializados antes de usar plugins.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Monitor App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily:
            'Plus Jakarta', // Usando una de tus fuentes definidas en pubspec.yaml
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _deviceId = 'Obteniendo ID del dispositivo...';
  String _apiToken = 'Obteniendo Token API...';

  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Método para inicializar el ID del dispositivo y el token de la API
  Future<void> _initializeData() async {
    try {
      // Obtener o crear el ID único del dispositivo
      final deviceId = await _dbHelper.getOrCreateDeviceId();
      // Obtener el token de la API
      final apiToken = await _dbHelper.getApiToken();

      setState(() {
        _deviceId = 'ID Dispositivo: $deviceId';
        _apiToken = 'Token API: ${apiToken ?? 'No disponible'}';
      });
    } catch (e) {
      setState(() {
        _deviceId = 'Error al obtener ID: $e';
        _apiToken = 'Error al obtener Token: $e';
      });
      print(
        'Error initializing data: $e',
      ); // Imprimir error en consola para depuración
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remote Device Monitor')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.devices_other,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 20),
              Text(
                'Bienvenido al Sistema de Monitoreo Remoto',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              // Mostrar el ID del dispositivo
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Información del Dispositivo:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _deviceId,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _apiToken,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Botones de acción (futuras funcionalidades)
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implementar lógica para iniciar recolección
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Iniciar recolección (próximamente)'),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar Recolección'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implementar lógica para detener recolección
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Detener recolección (próximamente)'),
                    ),
                  );
                },
                icon: const Icon(Icons.stop),
                label: const Text('Detener Recolección'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                  backgroundColor:
                      Colors.redAccent, // Color diferente para detener
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
