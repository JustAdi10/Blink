enum TransferStatus {
  pending,
  inProgress,
  completed,
  failed,
}

enum TransferType {
  sending,
  receiving,
}

class TransferInfo {
  final String id;
  final String fileName;
  final int fileSize;
  final String? filePath;
  final TransferType type;
  final TransferStatus status;
  final double progress;
  final String? errorMessage;
  final DateTime startTime;
  final DateTime? endTime;

  const TransferInfo({
    required this.id,
    required this.fileName,
    required this.fileSize,
    this.filePath,
    required this.type,
    this.status = TransferStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    required this.startTime,
    this.endTime,
  });

  TransferInfo copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    String? filePath,
    TransferType? type,
    TransferStatus? status,
    double? progress,
    String? errorMessage,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return TransferInfo(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  String toString() {
    return 'TransferInfo(id: $id, fileName: $fileName, fileSize: $fileSize, type: $type, status: $status, progress: $progress)';
  }
}
