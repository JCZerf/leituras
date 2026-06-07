import '../models/ponto_consumo.dart';
import '../models/ponto_consumo_resumo.dart';
import 'app_database.dart';

class PontoConsumoRepository {
  const PontoConsumoRepository(this._database);

  final AppDatabase _database;

  Future<List<PontoConsumoResumo>> findResumoByGrupoId(int grupoId) async {
    final db = await _database.database;
    final maps = await db.rawQuery(
      '''
      SELECT
        pc.id,
        pc.grupo_id,
        pc.instalacao,
        pc.numero_medidor,
        pc.endereco,
        hl.id AS ultima_leitura_id,
        hl.valor_leitura AS ultima_valor_leitura,
        hl.data_leitura AS ultima_data_leitura,
        hl.foto_path AS ultima_foto_path,
        hl.foto_descricao AS ultima_foto_descricao
      FROM pontos_consumo pc
      LEFT JOIN historico_leituras hl
        ON hl.id = (
          SELECT h.id
          FROM historico_leituras h
          WHERE h.ponto_consumo_id = pc.id
          ORDER BY h.data_leitura DESC, h.id DESC
          LIMIT 1
        )
      WHERE pc.grupo_id = ?
      ORDER BY pc.id DESC
      ''',
      [grupoId],
    );
    return maps.map(PontoConsumoResumo.fromMap).toList();
  }

  Future<PontoConsumo?> findById(int id) async {
    final db = await _database.database;
    final maps = await db.query(
      'pontos_consumo',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return PontoConsumo.fromMap(maps.first);
  }

  Future<int> insert(PontoConsumo ponto) async {
    final db = await _database.database;
    return db.insert('pontos_consumo', ponto.toMap()..remove('id'));
  }
}
