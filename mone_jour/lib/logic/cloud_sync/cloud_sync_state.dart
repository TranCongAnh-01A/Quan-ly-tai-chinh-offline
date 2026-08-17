import 'package:equatable/equatable.dart';

sealed class CloudSyncState extends Equatable {
  const CloudSyncState();

  @override
  List<Object?> get props => [];
}

class CloudSyncInitial extends CloudSyncState {}

class CloudSyncLoading extends CloudSyncState {}

class CloudSyncConnected extends CloudSyncState {
  final String email;
  final String? lastSyncTime;
  
  const CloudSyncConnected({required this.email, this.lastSyncTime});

  @override
  List<Object?> get props => [email, lastSyncTime];
}

class CloudSyncError extends CloudSyncState {
  final String message;
  
  const CloudSyncError(this.message);

  @override
  List<Object?> get props => [message];
}

class CloudSyncSuccess extends CloudSyncState {
  final String message;
  final String email;
  final String? lastSyncTime;
  
  const CloudSyncSuccess({
    required this.message, 
    required this.email, 
    this.lastSyncTime,
  });

  @override
  List<Object?> get props => [message, email, lastSyncTime];
}
