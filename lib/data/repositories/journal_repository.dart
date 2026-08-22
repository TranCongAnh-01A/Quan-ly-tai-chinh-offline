import 'package:isar/isar.dart';

import '../../services/database_service.dart';
import '../models/journal.dart';

class JournalRepository {
  Isar get _db => DatabaseService.instance;

  Future<void> add(Journal journal) async {
    await _db.writeTxn(() => _db.journals.put(journal));
  }

  Future<void> update(Journal journal) async {
    await _db.writeTxn(() => _db.journals.put(journal));
  }

  Future<void> delete(int id) async {
    await _db.writeTxn(() => _db.journals.delete(id));
  }

  Future<List<Journal>> getAll() async {
    return _db.journals.where().sortByDateDesc().findAll();
  }

  Stream<void> watchChanges() {
    return _db.journals.watchLazy();
  }
}
