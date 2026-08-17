import 'package:equatable/equatable.dart';
import '../../data/models/journal.dart';

abstract class JournalState extends Equatable {
  const JournalState();

  @override
  List<Object?> get props => [];
}

class JournalInitial extends JournalState {}

class JournalLoading extends JournalState {}

class JournalLoaded extends JournalState {
  final List<Journal> journals;

  const JournalLoaded(this.journals);

  @override
  List<Object?> get props => [journals];
}

class JournalError extends JournalState {
  final String message;

  const JournalError(this.message);

  @override
  List<Object?> get props => [message];
}
