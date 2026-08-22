import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/journal.dart';
import '../../data/repositories/journal_repository.dart';
import 'journal_state.dart';

class JournalCubit extends Cubit<JournalState> {
  final JournalRepository _repository;
  StreamSubscription<void>? _subscription;

  JournalCubit(this._repository) : super(JournalInitial()) {
    _subscription = _repository.watchChanges().listen((_) {
      loadJournals();
    });
  }

  Future<void> loadJournals() async {
    try {
      emit(JournalLoading());
      final journals = await _repository.getAll();
      emit(JournalLoaded(journals));
    } catch (e) {
      emit(JournalError(e.toString()));
    }
  }

  Future<void> addJournal({
    String? title,
    required String content,
    required DateTime date,
  }) async {
    try {
      final journal = Journal()
        ..title = title
        ..content = content
        ..date = date;
      await _repository.add(journal);
    } catch (e) {
      emit(JournalError(e.toString()));
    }
  }

  Future<void> updateJournal(Journal journal) async {
    try {
      await _repository.update(journal);
    } catch (e) {
      emit(JournalError(e.toString()));
    }
  }

  Future<void> deleteJournal(int id) async {
    try {
      await _repository.delete(id);
    } catch (e) {
      emit(JournalError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
