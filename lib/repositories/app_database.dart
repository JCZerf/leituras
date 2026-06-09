import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? databaseFactory, String? databasePath})
    : _databaseFactory = databaseFactory,
      _databasePath = databasePath;

  static const String databaseName = 'leituras.db';
  static const int databaseVersion = 5;

  final DatabaseFactory? _databaseFactory;
  final String? _databasePath;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final factory = _databaseFactory ?? databaseFactory;
    final path =
        _databasePath ?? p.join(await getDatabasesPath(), databaseName);

    _database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _migrateToVersion2(db);
          }
          if (oldVersion < 3) {
            await _migrateToVersion3(db);
          }
          if (oldVersion < 4) {
            await _migrateToVersion4(db);
          }
          if (oldVersion < 5) {
            await _migrateToVersion5(db);
          }
        },
      ),
    );

    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE grupos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        descricao TEXT,
        data_criacao TEXT NOT NULL
      )
    ''');

    await _createPontosConsumoSchema(db);
    await _createHistoricoLeiturasSchema(db);
  }

  Future<void> _createPontosConsumoSchema(Database db) async {
    await db.execute('''
      CREATE TABLE pontos_consumo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grupo_id INTEGER NOT NULL,
        instalacao TEXT,
        numero_medidor TEXT,
        endereco TEXT,
        is_interno INTEGER NOT NULL DEFAULT 0,
        is_composto INTEGER NOT NULL DEFAULT 0,
        is_desabitado INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (grupo_id) REFERENCES grupos (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_pontos_consumo_grupo_id
      ON pontos_consumo (grupo_id)
    ''');
  }

  Future<void> _createHistoricoLeiturasSchema(Database db) async {
    await db.execute('''
      CREATE TABLE historico_leituras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ponto_consumo_id INTEGER NOT NULL,
        valor_leitura INTEGER NOT NULL,
        valor_producao INTEGER,
        data_leitura TEXT NOT NULL,
        foto_path TEXT,
        foto_descricao TEXT,
        FOREIGN KEY (ponto_consumo_id)
          REFERENCES pontos_consumo (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_historico_leituras_ponto_data
      ON historico_leituras (ponto_consumo_id, data_leitura DESC, id DESC)
    ''');
  }

  Future<void> _migrateToVersion2(Database db) async {
    await _createPontosConsumoSchema(db);
    await _createHistoricoLeiturasSchema(db);

    final oldTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'leituras'",
    );
    if (oldTables.isEmpty) {
      return;
    }

    final oldRows = await db.query('leituras', orderBy: 'id ASC');
    final now = _formatSqliteDateTime(DateTime.now());

    for (final row in oldRows) {
      final pontoId = await db.insert('pontos_consumo', {
        'grupo_id': row['grupo_id'],
        'instalacao': row['instalacao'],
        'numero_medidor': row['numero_medidor'],
        'endereco': row['endereco'],
      });

      await db.insert('historico_leituras', {
        'ponto_consumo_id': pontoId,
        'valor_leitura': row['leitura'],
        'data_leitura': now,
        'foto_path': row['foto_path'],
        'foto_descricao': row['foto_descricao'],
      });
    }

    await db.execute('DROP TABLE leituras');
  }

  Future<void> _migrateToVersion3(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'pontos_consumo',
      column: 'is_interno',
      definition: 'is_interno INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _migrateToVersion4(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'pontos_consumo',
      column: 'is_composto',
      definition: 'is_composto INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'historico_leituras',
      column: 'valor_producao',
      definition: 'valor_producao INTEGER',
    );
  }

  Future<void> _migrateToVersion5(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'pontos_consumo',
      column: 'is_desabitado',
      definition: 'is_desabitado INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((item) => item['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $definition');
    }
  }

  String _formatSqliteDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
