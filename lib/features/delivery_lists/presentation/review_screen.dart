import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../capture/presentation/capture_bloc.dart';
import '../data/local_delivery_repository.dart';
import '../domain/delivery_models.dart';
import 'export_preview_screen.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, required this.repository});

  final LocalDeliveryRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CaptureBloc, CaptureState>(
      builder: (context, state) {
        final list = state.list;
        return Scaffold(
          appBar: AppBar(title: Text(list.title)),
          body: list.items.isEmpty
              ? const Center(child: Text('Nenhuma encomenda nesta lista.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: list.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = list.items[index];
                    final needsReview =
                        item.status == ParcelStatus.needsReview ||
                        item.name == null ||
                        item.name!.trim().isEmpty;
                    return Card(
                      child: ListTile(
                        onTap: () => _edit(context, item),
                        leading: CircleAvatar(
                          backgroundColor: needsReview
                              ? Theme.of(context).colorScheme.errorContainer
                              : Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            needsReview ? Icons.warning_amber : Icons.check,
                          ),
                        ),
                        title: Text(
                          item.name?.trim().isNotEmpty == true
                              ? item.name!
                              : 'Nome não identificado',
                        ),
                        subtitle: Text(
                          needsReview
                              ? 'Toque para conferir a foto e corrigir'
                              : 'Toque para conferir ou editar',
                        ),
                        trailing: IconButton(
                          tooltip: 'Remover',
                          onPressed: () => _confirmRemove(context, item),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    );
                  },
                ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed:
                  list.items.any((item) => item.name?.trim().isNotEmpty == true)
                  ? () => _previewExport(context, list)
                  : null,
              icon: const Icon(Icons.article_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Revisar texto'),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, ParcelItem item) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EditParcelDialog(
        initialName: item.name ?? '',
        imagePath: item.imagePath,
      ),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      context.read<CaptureBloc>().add(ParcelNameChanged(item.id, result));
    }
  }

  Future<void> _confirmRemove(BuildContext context, ParcelItem item) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover encomenda?'),
        content: Text(item.name ?? 'Este item não identificado será removido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (remove == true && context.mounted) {
      context.read<CaptureBloc>().add(ParcelRemoved(item.id));
    }
  }

  Future<void> _previewExport(BuildContext context, DeliveryList list) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ExportPreviewScreen(list: list, repository: repository),
      ),
    );
  }
}

class _EditParcelDialog extends StatefulWidget {
  const _EditParcelDialog({required this.initialName, required this.imagePath});

  final String initialName;
  final String imagePath;

  @override
  State<_EditParcelDialog> createState() => _EditParcelDialogState();
}

class _EditParcelDialogState extends State<_EditParcelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imagePath);
    return AlertDialog(
      title: const Text('Conferir encomenda'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (file.existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(file, fit: BoxFit.contain),
                )
              else
                const ListTile(
                  leading: Icon(Icons.image_not_supported_outlined),
                  title: Text('A foto já expirou ou não está disponível.'),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome da pessoa',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      Navigator.pop(context, name);
    }
  }
}
