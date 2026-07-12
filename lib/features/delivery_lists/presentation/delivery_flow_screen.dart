import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../capture/data/ocr_service.dart';
import '../../capture/presentation/capture_bloc.dart';
import '../../capture/presentation/capture_screen.dart';
import '../data/local_delivery_repository.dart';
import '../domain/delivery_models.dart';
import 'review_screen.dart';

class DeliveryFlowScreen extends StatelessWidget {
  const DeliveryFlowScreen({
    super.key,
    required this.list,
    required this.repository,
    required this.retentionDays,
    this.reviewOnly = false,
  });

  final DeliveryList list;
  final LocalDeliveryRepository repository;
  final int retentionDays;
  final bool reviewOnly;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CaptureBloc(
        list: list,
        repository: repository,
        ocrService: OcrService(),
        retentionDays: retentionDays,
        initialPhase: reviewOnly ? CapturePhase.review : CapturePhase.capturing,
      ),
      child: BlocBuilder<CaptureBloc, CaptureState>(
        buildWhen: (previous, current) => previous.phase != current.phase,
        builder: (context, state) => state.phase == CapturePhase.review
            ? ReviewScreen(repository: repository)
            : const CaptureScreen(),
      ),
    );
  }
}
