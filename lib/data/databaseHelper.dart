import 'dart:async';
import 'dart:convert'; // Para base64Url
import 'dart:math'; // Para Random
import 'dart:io'; // Para Platform
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
    // Inicializa FFI solo si es necesario (escritorio)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit(); // Configura el entorno FFI
      databaseFactory = databaseFactoryFfi; // Usa la fábrica FFI
    }

    // Obtiene la ruta de la base de datos
    String path;
    if (Platform.isAndroid || Platform.isIOS) {
      // Para móvil: usa getDatabasesPath()
      final databasesPath = await getDatabasesPath();
      path = join(databasesPath, 'remote_monitor.db');
    } else {
      // Para escritorio: usa una ruta local (ejemplo: directorio actual)
      path = join(Directory.current.path, 'remote_monitor.db');
    }

    // Abre la base de datos
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
  Future<String> getApiToken() async {
    final db = await database;

    // Intenta obtener el token existente
    final result = await db.query(tableAuth, limit: 1);

    if (result.isNotEmpty && result.first['api_token'] != null) {
      return result.first['api_token'] as String;
    }

    // Si no hay token, genera uno nuevo
    final newToken = _generateUniqueToken();
    await setApiToken(newToken);
    return newToken;
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
    try {
      // Intenta obtener el ID almacenado
      final storedDeviceId = await getConfigValue('device_id_key');
      if (storedDeviceId != null && storedDeviceId.isNotEmpty) {
        return storedDeviceId;
      }

      // Si no existe, genera uno nuevo
      final deviceInfo = DeviceInfoPlugin();
      String newDeviceId;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        newDeviceId =
            androidInfo.id ?? const Uuid().v4(); // Usa Android ID o genera UUID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        newDeviceId = iosInfo.identifierForVendor ?? const Uuid().v4();
      } else {
        newDeviceId = const Uuid().v4(); // Para Windows/otros
      }

      // Guarda el nuevo ID
      await setConfigValue('device_id_key', newDeviceId);
      return newDeviceId;
    } catch (e) {
      // Si algo falla, devuelve un UUID como último recurso
      return const Uuid().v4();
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
