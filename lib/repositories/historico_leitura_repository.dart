import '../models/historico_leitura.dart';
import 'app_database.dart';

class HistoricoLeituraRepository {
  const HistoricoLeituraRepository(this._database);

  final AppDatabase _database;

  Future<List<HistoricoLeitura>> findByPontoConsumoId(
    int pontoConsumoId,
  ) async {
    final db = await _database.database;
    final maps = await db.query(
      'historico_leituras',
      where: 'ponto_consumo_id = ?',
      whereArgs: [pontoConsumoId],
      orderBy: 'data_leitura DESC, id DESC',
    );
    return maps.map(HistoricoLeitura.fromMap).toList();
  }

  Future<int> insert(HistoricoLeitura historico) async {
    final db = await _database.database;
    return db.insert('historico_leituras', historico.toMap()..remove('id'));
  }
}
