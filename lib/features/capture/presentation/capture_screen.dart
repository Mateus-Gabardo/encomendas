import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../delivery_lists/domain/delivery_models.dart';
import 'capture_bloc.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.canReturnToReview});

  final bool canReturnToReview;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Object? _error;
  bool _takingPhoto = false;
  bool _finishing = false;
  bool _syncedInitialList = false;
  int _capturedCount = 0;
  String? _editingItemId;
  String? _confirmedItemId;
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedInitialList) return;
    _syncedInitialList = true;
    final latest = context.read<CaptureBloc>().state.list.items.lastOrNull;
    if (latest == null) return;
    _editingItemId = latest.id;
    _confirmedItemId = latest.id;
    _nameController.text = latest.name ?? '';
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      final camera = back.isEmpty ? cameras.first : back.first;
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        return controller.dispose();
      }
      setState(() => _controller = controller);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (_takingPhoto ||
        _finishing ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _takingPhoto = true);
    try {
      final photo = await controller.takePicture();
      if (!mounted) return;
      context.read<CaptureBloc>().add(PhotoCaptured(photo.path));
      setState(() => _capturedCount++);
    } on CameraException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nao foi possivel tirar a foto: ${error.description ?? error.code}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  void _finish() {
    final hasItems = context.read<CaptureBloc>().state.list.items.isNotEmpty;
    if (!hasItems || _finishing) return;
    setState(() => _finishing = true);
    context.read<CaptureBloc>().add(const CaptureFinished());
  }

  void _close() {
    if (widget.canReturnToReview) {
      FocusScope.of(context).unfocus();
      context.read<CaptureBloc>().add(const CaptureCanceled());
      return;
    }
    Navigator.pop(context);
  }

  void _syncLastItem(CaptureState state) {
    final latest = state.list.items.lastOrNull;
    if (latest == null) {
      _editingItemId = null;
      _nameController.clear();
      return;
    }
    if (_editingItemId != latest.id || !_nameFocusNode.hasFocus) {
      _editingItemId = latest.id;
      _nameController.text = latest.name ?? '';
    }
  }

  void _saveQuickName() {
    final itemId = _editingItemId;
    final name = _nameController.text.trim();
    if (itemId == null || name.isEmpty) return;
    context.read<CaptureBloc>().add(ParcelNameChanged(itemId, name));
    setState(() => _confirmedItemId = itemId);
    FocusScope.of(context).unfocus();
  }

  void _discardQuickPhoto() {
    final itemId = _editingItemId;
    if (itemId == null) return;
    final items = context.read<CaptureBloc>().state.list.items;
    final itemIndex = items.indexWhere((item) => item.id == itemId);
    final previousItemId = itemIndex > 0 ? items[itemIndex - 1].id : null;
    context.read<CaptureBloc>().add(ParcelRemoved(itemId));
    setState(() {
      _capturedCount = _capturedCount > 0 ? _capturedCount - 1 : 0;
      _editingItemId = previousItemId;
      _confirmedItemId = previousItemId;
      if (previousItemId == null) {
        _nameController.clear();
      }
    });
    FocusScope.of(context).unfocus();
  }

  void _openCapturedPhotos() {
    final hasItems = context.read<CaptureBloc>().state.list.items.isNotEmpty;
    if (!hasItems || _takingPhoto || _finishing) return;
    FocusScope.of(context).unfocus();
    context.read<CaptureBloc>().add(const CaptureFinished());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capturar encomendas')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nao foi possivel abrir a camera. Verifique a permissao do aplicativo.\n\n$_error',
            ),
          ),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return BlocListener<CaptureBloc, CaptureState>(
      listener: (context, state) => _syncLastItem(state),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: CameraPreview(controller)),
              const _NameGuideOverlay(),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _CaptureTopBar(
                  canFinish: context
                      .watch<CaptureBloc>()
                      .state
                      .list
                      .items
                      .isNotEmpty,
                  finishing: _finishing,
                  onClose: _close,
                  onFinish: _finish,
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 122,
                child: BlocBuilder<CaptureBloc, CaptureState>(
                  builder: (context, state) {
                    final latest = state.list.items.lastOrNull;
                    final showPanel =
                        latest != null && latest.id != _confirmedItemId;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: !showPanel
                          ? const _CaptureHintPanel()
                          : _QuickConfirmPanel(
                              key: ValueKey(latest.id),
                              item: latest,
                              controller: _nameController,
                              focusNode: _nameFocusNode,
                              onSave: _saveQuickName,
                              onDiscard: _discardQuickPhoto,
                            ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 28,
                left: 0,
                right: 0,
                child: BlocBuilder<CaptureBloc, CaptureState>(
                  builder: (context, state) {
                    final totalCount = state.list.items.length;
                    final latestItem = state.list.items.lastOrNull;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 82,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _CapturedPhotosButton(
                              count: totalCount,
                              imagePath:
                                  latestItem?.cropPath ?? latestItem?.imagePath,
                              enabled:
                                  totalCount > 0 &&
                                  !_takingPhoto &&
                                  !_finishing,
                              onPressed: _openCapturedPhotos,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Semantics(
                          label: 'Tirar foto da etiqueta',
                          button: true,
                          child: InkWell(
                            onTap: _takePhoto,
                            customBorder: const CircleBorder(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _takingPhoto
                                    ? Colors.grey
                                    : const Color(0xffffd166),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 18,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: _takingPhoto
                                  ? const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 36,
                                      color: Colors.black,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 106),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapturedPhotosButton extends StatelessWidget {
  const _CapturedPhotosButton({
    required this.count,
    required this.imagePath,
    required this.enabled,
    required this.onPressed,
  });

  final int count;
  final String? imagePath;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final image = imagePath == null ? null : File(imagePath!);
    final backgroundColor = enabled
        ? Colors.black.withValues(alpha: .68)
        : Colors.black.withValues(alpha: .32);
    final foregroundColor = enabled ? Colors.white : Colors.white54;
    return Tooltip(
      message: 'Ver fotos capturadas',
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 58,
          height: 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: image != null && image.existsSync()
                      ? ColorFiltered(
                          colorFilter: enabled
                              ? const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.multiply,
                                )
                              : ColorFilter.mode(
                                  Colors.black.withValues(alpha: .35),
                                  BlendMode.darken,
                                ),
                          child: Image.file(image, fit: BoxFit.cover),
                        )
                      : Center(
                          child: Icon(
                            Icons.photo_library_outlined,
                            color: foregroundColor,
                            size: 24,
                          ),
                        ),
                ),
              ),
              Positioned(
                top: -7,
                right: -7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: enabled ? const Color(0xffffd166) : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: SizedBox.square(
                    dimension: 24,
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameGuideOverlay extends StatelessWidget {
  const _NameGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final guideWidth = constraints.maxWidth * .84;
          final guideHeight = constraints.maxHeight * .22;
          final horizontalMask = (constraints.maxWidth - guideWidth) / 2;
          final verticalMask = (constraints.maxHeight - guideHeight) / 2;
          final maskColor = Colors.black.withValues(alpha: .34);
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: verticalMask,
                child: ColoredBox(color: maskColor),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: verticalMask,
                child: ColoredBox(color: maskColor),
              ),
              Positioned(
                left: 0,
                top: verticalMask,
                width: horizontalMask,
                height: guideHeight,
                child: ColoredBox(color: maskColor),
              ),
              Positioned(
                right: 0,
                top: verticalMask,
                width: horizontalMask,
                height: guideHeight,
                child: ColoredBox(color: maskColor),
              ),
              Center(
                child: SizedBox(
                  width: guideWidth,
                  height: guideHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, -.18),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      'Enquadre o nome nesta area',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CaptureTopBar extends StatelessWidget {
  const _CaptureTopBar({
    required this.canFinish,
    required this.finishing,
    required this.onClose,
    required this.onFinish,
  });

  final bool canFinish;
  final bool finishing;
  final VoidCallback onClose;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton.filledTonal(
          onPressed: finishing ? null : onClose,
          icon: const Icon(Icons.close),
        ),
        if (finishing)
          const Chip(
            avatar: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: Text('Processando imagens...'),
          )
        else
          const Spacer(),
        FilledButton(
          onPressed: !canFinish || finishing ? null : onFinish,
          child: const Text('Concluir'),
        ),
      ],
    );
  }
}

class _CaptureHintPanel extends StatelessWidget {
  const _CaptureHintPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withValues(alpha: .62),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.center_focus_strong, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aponte a faixa para o nome e toque no botao da camera.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickConfirmPanel extends StatelessWidget {
  const _QuickConfirmPanel({
    super.key,
    required this.item,
    required this.controller,
    required this.focusNode,
    required this.onSave,
    required this.onDiscard,
  });

  final ParcelItem item;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final image = File(item.cropPath ?? item.imagePath);
    final processing =
        item.status == ParcelStatus.processing ||
        item.status == ParcelStatus.queued;
    final needsReview =
        item.status == ParcelStatus.needsReview ||
        item.name == null ||
        item.name!.trim().isEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: image.existsSync()
                  ? Image.file(image, width: 74, height: 74, fit: BoxFit.cover)
                  : Container(
                      width: 74,
                      height: 74,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        processing
                            ? Icons.sync
                            : needsReview
                            ? Icons.warning_amber
                            : Icons.check_circle,
                        size: 18,
                        color: processing
                            ? const Color(0xff118ab2)
                            : needsReview
                            ? const Color(0xffef476f)
                            : const Color(0xff06d6a0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        processing
                            ? 'Lendo nome...'
                            : needsReview
                            ? 'Confira o nome'
                            : 'Nome identificado',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !processing,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Nome da pessoa',
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSave(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Tooltip(
                        message: 'Descartar foto',
                        child: IconButton.outlined(
                          onPressed: processing ? null : onDiscard,
                          icon: const Icon(Icons.close),
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: processing ? null : onSave,
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Confirmo aceita o nome e libera a próxima foto.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
