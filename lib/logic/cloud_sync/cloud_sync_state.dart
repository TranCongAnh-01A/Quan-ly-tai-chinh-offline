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

  /// Trên Drive có bản sao lưu hay không — quyết định có cho bấm "Khôi phục".
  final bool hasRemoteBackup;

  const CloudSyncConnected({
    required this.email,
    this.lastSyncTime,
    this.hasRemoteBackup = false,
  });

  @override
  List<Object?> get props => [email, lastSyncTime, hasRemoteBackup];
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
  
  final bool hasRemoteBackup;

  const CloudSyncSuccess({
    required this.message,
    required this.email,
    this.lastSyncTime,
    this.hasRemoteBackup = false,
  });

  @override
  List<Object?> get props => [message, email, lastSyncTime, hasRemoteBackup];
}
