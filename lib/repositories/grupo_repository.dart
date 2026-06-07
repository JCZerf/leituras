import 'package:sqflite/sqflite.dart';

import '../models/grupo.dart';
import 'app_database.dart';

class GrupoRepository {
  const GrupoRepository(this._database);

  final AppDatabase _database;

  Future<List<Grupo>> findAll() async {
    final db = await _database.database;
    final maps = await db.query('grupos', orderBy: 'nome COLLATE NOCASE ASC');
    return maps.map(Grupo.fromMap).toList();
  }

  Future<Grupo?> findById(int id) async {
    final db = await _database.database;
    final maps = await db.query(
      'grupos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return Grupo.fromMap(maps.first);
  }

  Future<int> insert(Grupo grupo) async {
    final db = await _database.database;
    return db.insert('grupos', grupo.toMap()..remove('id'));
  }

  Future<int> update(Grupo grupo) async {
    final db = await _database.database;
    return db.update(
      'grupos',
      grupo.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [grupo.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _database.database;
    try {
      await db.delete('grupos', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (_) {
      throw ArgumentError(
        'Nao e possivel excluir um grupo com medidores ativos.',
      );
    }
  }
}
