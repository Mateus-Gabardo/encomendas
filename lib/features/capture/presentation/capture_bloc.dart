import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../delivery_lists/data/local_delivery_repository.dart';
import '../../delivery_lists/domain/delivery_models.dart';
import '../data/ocr_service.dart';

sealed class CaptureEvent {
  const CaptureEvent();
}

class PhotoCaptured extends CaptureEvent {
  const PhotoCaptured(this.temporaryPath);
  final String temporaryPath;
}

class CaptureFinished extends CaptureEvent {
  const CaptureFinished();
}

class CaptureResumed extends CaptureEvent {
  const CaptureResumed();
}

class CaptureCanceled extends CaptureEvent {
  const CaptureCanceled();
}

class ParcelNameChanged extends CaptureEvent {
  const ParcelNameChanged(this.itemId, this.name);
  final String itemId;
  final String name;
}

class ParcelRemoved extends CaptureEvent {
  const ParcelRemoved(this.itemId);
  final String itemId;
}

enum CapturePhase { capturing, finishing, review }

class CaptureState {
  const CaptureState({
    required this.list,
    this.phase = CapturePhase.capturing,
    this.canReturnToReviewOnCancel = false,
  });

  final DeliveryList list;
  final CapturePhase phase;
  final bool canReturnToReviewOnCancel;

  int get processingCount => list.items
      .where(
        (item) =>
            item.status == ParcelStatus.queued ||
            item.status == ParcelStatus.processing,
      )
      .length;

  CaptureState copyWith({
    DeliveryList? list,
    CapturePhase? phase,
    bool? canReturnToReviewOnCancel,
  }) => CaptureState(
    list: list ?? this.list,
    phase: phase ?? this.phase,
    canReturnToReviewOnCancel:
        canReturnToReviewOnCancel ?? this.canReturnToReviewOnCancel,
  );
}

class CaptureBloc extends Bloc<CaptureEvent, CaptureState> {
  CaptureBloc({
    required DeliveryList list,
    required this.repository,
    required this.ocrService,
    required this.retentionDays,
    CapturePhase initialPhase = CapturePhase.capturing,
  }) : super(CaptureState(list: list, phase: initialPhase)) {
    on<CaptureEvent>(_onEvent, transformer: sequential());
  }

  final LocalDeliveryRepository repository;
  final OcrService ocrService;
  final int retentionDays;

  Future<void> _onEvent(CaptureEvent event, Emitter<CaptureState> emit) async {
    switch (event) {
      case PhotoCaptured():
        await _processPhoto(event, emit);
      case CaptureFinished():
        final completed = state.list.copyWith(completedAt: DateTime.now());
        emit(
          state.copyWith(
            list: completed,
            phase: CapturePhase.review,
            canReturnToReviewOnCancel: false,
          ),
        );
        await repository.saveList(completed);
      case CaptureResumed():
        emit(
          state.copyWith(
            phase: CapturePhase.capturing,
            canReturnToReviewOnCancel: true,
          ),
        );
      case CaptureCanceled():
        emit(
          state.copyWith(
            phase: CapturePhase.review,
            canReturnToReviewOnCancel: false,
          ),
        );
      case ParcelNameChanged():
        final updated = _replaceItem(
          event.itemId,
          (item) => item.copyWith(
            name: event.name.trim(),
            confidence: 1,
            status: ParcelStatus.recognized,
          ),
        );
        emit(state.copyWith(list: updated));
        await repository.saveList(updated);
        await repository.addKnownName(event.name);
      case ParcelRemoved():
        final item = state.list.items
            .where((item) => item.id == event.itemId)
            .firstOrNull;
        if (item != null) {
          for (final path in [item.imagePath, item.cropPath]) {
            if (path != null) {
              await repository.deleteStoredFile(path);
            }
          }
        }
        final updated = state.list.copyWith(
          items: state.list.items
              .where((item) => item.id != event.itemId)
              .toList(),
        );
        emit(state.copyWith(list: updated));
        await repository.saveList(updated);
    }
  }

  Future<void> _processPhoto(
    PhotoCaptured event,
    Emitter<CaptureState> emit,
  ) async {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final retainedPath = await repository.retainPhoto(
      sourcePath: event.temporaryPath,
      listId: state.list.id,
      itemId: id,
    );
    var item = ParcelItem(
      id: id,
      imagePath: retainedPath,
      capturedAt: now,
      expiresAt: retentionDays == 0
          ? DateTime(9999, 12, 31)
          : now.add(Duration(days: retentionDays)),
      status: ParcelStatus.processing,
    );
    var updated = state.list.copyWith(items: [...state.list.items, item]);
    emit(state.copyWith(list: updated));

    try {
      final knownNames = await repository.loadKnownNames();
      final result = await ocrService.process(
        retainedPath,
        knownNames: knownNames,
      );
      item = item.copyWith(
        cropPath: result.cropPath,
        name: result.extraction.name,
        rawText: result.rawText,
        confidence: result.extraction.confidence,
        status:
            result.extraction.name != null &&
                result.extraction.confidence >= 0.7
            ? ParcelStatus.recognized
            : ParcelStatus.needsReview,
      );
    } on Object {
      item = item.copyWith(status: ParcelStatus.needsReview);
    }
    updated = _replaceItem(id, (_) => item);
    emit(state.copyWith(list: updated));
    await repository.saveList(updated);
  }

  DeliveryList _replaceItem(
    String id,
    ParcelItem Function(ParcelItem) change,
  ) => state.list.copyWith(
    items: state.list.items
        .map((item) => item.id == id ? change(item) : item)
        .toList(),
  );

  @override
  Future<void> close() async {
    await ocrService.close();
    return super.close();
  }
}
