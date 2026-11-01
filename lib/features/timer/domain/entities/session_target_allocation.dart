import 'package:equatable/equatable.dart';

class SessionTargetAllocation extends Equatable {
  const SessionTargetAllocation({
    this.targetId,
    required this.targetName,
    required this.percentage,
    this.allocatedSeconds = 0,
    this.displayOrder = 1,
    this.colorHex = '#00E5FF',
    this.backlogTaskId,
  });

  final int? targetId;
  final String targetName;
  final int percentage;
  final int allocatedSeconds;
  final int displayOrder;
  final String colorHex;
  final int? backlogTaskId;

  SessionTargetAllocation copyWith({
    int? targetId,
    String? targetName,
    int? percentage,
    int? allocatedSeconds,
    int? displayOrder,
    String? colorHex,
    int? backlogTaskId,
  }) {
    return SessionTargetAllocation(
      targetId: targetId ?? this.targetId,
      targetName: targetName ?? this.targetName,
      percentage: percentage ?? this.percentage,
      allocatedSeconds: allocatedSeconds ?? this.allocatedSeconds,
      displayOrder: displayOrder ?? this.displayOrder,
      colorHex: colorHex ?? this.colorHex,
      backlogTaskId: backlogTaskId ?? this.backlogTaskId,
    );
  }

  @override
  List<Object?> get props => [
        targetId,
        targetName,
        percentage,
        allocatedSeconds,
        displayOrder,
        colorHex,
        backlogTaskId,
      ];
}
