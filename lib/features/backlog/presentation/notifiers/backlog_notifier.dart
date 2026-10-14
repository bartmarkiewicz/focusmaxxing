import 'package:flutter/foundation.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/add_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/delete_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/get_pending_tasks_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';

class BacklogNotifier extends ChangeNotifier {
  final GetPendingTasksUseCase getPendingTasksUseCase;
  final AddBacklogTaskUseCase addBacklogTaskUseCase;
  final DeleteBacklogTaskUseCase deleteBacklogTaskUseCase;
  final MarkTaskCompletedUseCase markTaskCompletedUseCase;

  List<BacklogTaskEntity> _pendingTasks = const [];
  BacklogTaskEntity? _selectedTask;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  BacklogNotifier({
    required this.getPendingTasksUseCase,
    required this.addBacklogTaskUseCase,
    required this.deleteBacklogTaskUseCase,
    required this.markTaskCompletedUseCase,
  });

  List<BacklogTaskEntity> get pendingTasks => _pendingTasks;
  BacklogTaskEntity? get selectedTask => _selectedTask;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void selectTaskAsGoal(BacklogTaskEntity? task) {
    _selectedTask = task;
    notifyListeners();
  }

  Future<void> loadPendingTasks({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final result = await getPendingTasksUseCase();
    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (tasks) {
        _pendingTasks = List.unmodifiable(tasks);
        _errorMessage = null;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addTask(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;

    _errorMessage = null;
    final result = await addBacklogTaskUseCase(trimmed);
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (id) async {
        await loadPendingTasks(showLoading: false);
        return true;
      },
    );
  }

  Future<void> deleteTask(int id) async {
    final previousTasks = _pendingTasks;
    _pendingTasks = List.unmodifiable(
      _pendingTasks.where((task) => task.id != id),
    );
    _errorMessage = null;
    notifyListeners();

    final result = await deleteBacklogTaskUseCase(id);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _pendingTasks = previousTasks;
        notifyListeners();
      },
      (_) {},
    );
  }

  Future<void> completeTask(int id, int sessionId) async {
    final previousTasks = _pendingTasks;
    _pendingTasks = List.unmodifiable(
      _pendingTasks.where((task) => task.id != id),
    );
    if (_selectedTask?.id == id) {
      _selectedTask = null;
    }
    _errorMessage = null;
    notifyListeners();

    final result = await markTaskCompletedUseCase(id: id, sessionId: sessionId);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _pendingTasks = previousTasks;
        notifyListeners();
      },
      (_) {},
    );
  }
}
