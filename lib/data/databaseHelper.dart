import 'dart:async';
import 'dart:convert'; // Para base64Url
import 'dart:math'; // Para Random

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // Necesario para getDatabasesPath

// Dependencias para Device ID
import 'package:device_info_plus/device_info_plus.dart'; // Para obtener info del dispositivo
import 'package:uuid/uuid.dart'; // Para generar UUIDs si es necesario

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // Nombres de las tablas
  static const String tableSensorData = 'sensor_data';
  static const String tableAuth = 'auth_credentials';
  static const String tableDeviceStatus = 'device_status';
  static const String tableConfig = 'app_config';

  // Campos comunes
  static const String colId = 'id';
  static const String colDeviceId = 'device_id';
  static const String colTimestamp = 'timestamp';

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Obtiene la ruta al directorio de bases de datos de la aplicación.
    String databasesPath =
        await getDatabasesPath(); // path_provider es necesario para esta función
    String path = join(databasesPath, 'remote_monitor.db');

    // Abre la base de datos. Si no existe, la crea.
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Puedes añadir lógica de actualización aquí
    );
  }

  // Método para crear las tablas cuando la base de datos se crea por primera vez
  Future<void> _onCreate(Database db, int version) async {
    // Tabla sensor_data (mejorada con índices)
    await db.execute('''
      CREATE TABLE $tableSensorData(
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        $colTimestamp INTEGER NOT NULL,
        $colDeviceId TEXT NOT NULL
      )
    ''');

    // Índice para búsquedas por tiempo
    await db.execute('''
      CREATE INDEX idx_timestamp ON $tableSensorData($colTimestamp);
    ''');

    // Índice para búsquedas por dispositivo
    await db.execute('''
      CREATE INDEX idx_device_id ON $tableSensorData($colDeviceId);
    ''');

    // Tabla auth_credentials (para el token de API)
    await db.execute('''
      CREATE TABLE $tableAuth(
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        api_token TEXT UNIQUE NOT NULL
      )
    ''');

    // Nueva tabla para estado del dispositivo
    await db.execute('''
      CREATE TABLE $tableDeviceStatus(
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colDeviceId TEXT NOT NULL,
        battery_level INTEGER NOT NULL,
        network_status TEXT NOT NULL,
        storage_available REAL NOT NULL,
        os_version TEXT NOT NULL,
        device_model TEXT NOT NULL,
        $colTimestamp INTEGER NOT NULL
      )
    ''');

    // Tabla para configuración
    await db.execute('''
      CREATE TABLE $tableConfig(
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        config_key TEXT UNIQUE NOT NULL,
        config_value TEXT NOT NULL
      )
    ''');

    // Insertar configuraciones por defecto
    await _insertDefaultConfig(db);

    // Generar y insertar token único para la API
    final uniqueToken = _generateUniqueToken();
    await db.insert(tableAuth, {'api_token': uniqueToken});
  }

  // Método para manejar actualizaciones de la base de datos (cambios de esquema)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Lógica de migración aquí. Por ahora, no hay cambios en la versión 1.
    // Si en el futuro incrementas la versión de la DB, añadirías aquí las ALTER TABLE.
  }

  Future<void> _insertDefaultConfig(Database db) async {
    const defaultConfig = {
      'sampling_interval': '30000', // 30 segundos en ms
      'active_days': '1,2,3,4,5', // Lunes a Viernes
      'active_hours': '8,22', // 8am a 10pm
      'gps_accuracy': 'high',
      'device_id_key':
          '', // Placeholder para el ID del dispositivo que se generará
    };

    for (final entry in defaultConfig.entries) {
      await db.insert(tableConfig, {
        'config_key': entry.key,
        'config_value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  String _generateUniqueToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  // ===== OPERACIONES MEJORADAS DE LA BASE DE DATOS =====

  // --- Operaciones de Configuración ---
  Future<String?> getConfigValue(String key) async {
    final db = await database;
    final result = await db.query(
      tableConfig,
      where: 'config_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return result.isNotEmpty ? result.first['config_value'] as String : null;
  }

  Future<int> setConfigValue(String key, String value) async {
    final db = await database;
    return db.insert(tableConfig, {
      'config_key': key,
      'config_value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Operaciones de Datos de Sensores (GPS) ---
  Future<int> insertSensorData(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      tableSensorData,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSensorData({
    int? startTime,
    int? endTime,
    int?
    deviceId, // Opcional: filtrar por ID de dispositivo si lo necesitas en el futuro
    int limit = 100, // Límite por defecto para paginación
    int offset = 0, // Offset por defecto para paginación
  }) async {
    final db = await database;

    String whereClause = '1=1'; // Cláusula base para construir el WHERE
    List<Object?> whereArgs = [];

    if (startTime != null && endTime != null) {
      whereClause += ' AND $colTimestamp BETWEEN ? AND ?';
      whereArgs.addAll([startTime, endTime]);
    }
    // Puedes añadir más condiciones de filtro aquí, ej:
    // if (deviceId != null) {
    //   whereClause += ' AND $colDeviceId = ?';
    //   whereArgs.add(deviceId);
    // }

    return db.query(
      tableSensorData,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: '$colTimestamp ASC',
      limit: limit,
      offset: offset,
    );
  }

  // --- Operaciones de Estado del Dispositivo ---
  Future<int> saveDeviceStatus(Map<String, dynamic> status) async {
    final db = await database;
    return db.insert(
      tableDeviceStatus,
      status,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>> getLatestDeviceStatus() async {
    final db = await database;
    final result = await db.query(
      tableDeviceStatus,
      orderBy: '$colTimestamp DESC',
      limit: 1,
    );
    return result.isNotEmpty ? result.first : {};
  }

  // --- Operaciones de Autenticación ---
  Future<String?> getApiToken() async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(tableAuth, limit: 1);
    if (result.isNotEmpty) {
      return result.first['api_token'] as String;
    }
    return null;
  }

  Future<int> setApiToken(String newToken) async {
    final db = await database;
    // Siempre actualizamos el primer (y único) registro o insertamos si no existe.
    return await db.insert(
      tableAuth,
      {
        'id': 1,
        'api_token': newToken,
      }, // Usamos id: 1 para asegurar que siempre haya un solo token
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Gestión de Device ID persistente ---
  Future<String> getOrCreateDeviceId() async {
    final storedDeviceId = await getConfigValue('device_id_key');
    if (storedDeviceId != null && storedDeviceId.isNotEmpty) {
      return storedDeviceId;
    } else {
      // Si no hay un ID guardado, genera uno
      final deviceInfo = DeviceInfoPlugin();
      String newDeviceId;

      if (await deviceInfo.androidInfo != null) {
        // En Android, usa el Android ID si está disponible
        final androidInfo = await deviceInfo.androidInfo;
        newDeviceId = androidInfo.id;
      } else if (await deviceInfo.iosInfo != null) {
        // En iOS, usa el identifierForVendor si está disponible
        final iosInfo = await deviceInfo.iosInfo;
        newDeviceId =
            iosInfo.identifierForVendor ?? const Uuid().v4(); // Fallback a UUID
      } else {
        // Para otras plataformas o si no se puede obtener, genera un UUID
        newDeviceId = const Uuid().v4();
      }

      // Guarda el nuevo ID en la configuración
      await setConfigValue('device_id_key', newDeviceId);
      return newDeviceId;
    }
  }

  // Método para cerrar la base de datos (opcional, útil para pruebas o cierre de app)
  Future<void> close() async {
    final db = await _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database =
          null; // Reinicia la instancia para que se vuelva a abrir si es necesario
    }
  }
}
