import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/local_delivery_repository.dart';
import '../domain/delivery_models.dart';
import '../domain/share_formatter.dart';

class ExportPreviewScreen extends StatefulWidget {
  const ExportPreviewScreen({
    super.key,
    required this.list,
    required this.repository,
  });

  final DeliveryList list;
  final LocalDeliveryRepository repository;

  @override
  State<ExportPreviewScreen> createState() => _ExportPreviewScreenState();
}

class _ExportPreviewScreenState extends State<ExportPreviewScreen> {
  final _controller = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadText();
  }

  Future<void> _loadText() async {
    final template = await widget.repository.getExportTemplate();
    final text = ShareFormatter().format(
      title: widget.list.title,
      date: widget.list.createdAt,
      names: widget.list.items.map((item) => item.name ?? ''),
      template: template,
    );
    if (!mounted) return;
    setState(() {
      _controller.text = text;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Texto para compartilhar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                Text(
                  'Edite o texto antes de enviar.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  minLines: 12,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    labelText: 'Mensagem',
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _loading ? null : _share,
          icon: const Icon(Icons.share),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Compartilhar'),
          ),
        ),
      ),
    );
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: _controller.text.trim(),
        title: widget.list.title,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    await widget.repository.saveList(
      widget.list.copyWith(sentAt: DateTime.now()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lista marcada como enviada.')),
    );
  }
}
