import 'package:flutter/material.dart';

import '../data/local_delivery_repository.dart';
import '../domain/delivery_models.dart';
import '../domain/share_formatter.dart';
import 'delivery_flow_screen.dart';

String _formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final LocalDeliveryRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DeliveryList> _lists = const [];
  int _retentionDays = 14;
  bool _loading = true;
  int _currentTab = 0;

  static const _presets = [
    'Entregas Mercado Livre',
    'Entregas Shopee',
    'Entregas Shein',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.repository.deleteExpiredPhotos();
    final lists = await widget.repository.loadLists();
    final retention = await widget.repository.getRetentionDays();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _retentionDays = retention;
      _loading = false;
    });
  }

  Future<void> _newList() async {
    final title = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ListTypePicker(presets: _presets),
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    final list = DeliveryList(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      createdAt: DateTime.now(),
    );
    await widget.repository.saveList(list);
    if (!mounted) return;
    await _openFlow(list);
  }

  Future<void> _openFlow(DeliveryList list, {bool reviewOnly = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DeliveryFlowScreen(
          list: list,
          repository: widget.repository,
          retentionDays: _retentionDays,
          reviewOnly: reviewOnly,
        ),
      ),
    );
    await _load();
  }

  Future<void> _deleteList(DeliveryList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lista?'),
        content: Text(
          'A lista "${list.title}" e suas fotos salvas serão removidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.deleteList(list.id);
    await _load();
  }

  Future<void> _changeRetention() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Guardar fotos por'),
        children: [7, 14]
            .map(
              (days) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, days),
                child: Row(
                  children: [
                    Icon(
                      days == _retentionDays
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                    ),
                    const SizedBox(width: 12),
                    Text('$days dias'),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null) return;
    await widget.repository.setRetentionDays(selected);
    if (mounted) setState(() => _retentionDays = selected);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeDashboard(
        lists: _lists,
        loading: _loading,
        retentionDays: _retentionDays,
        onNewList: _newList,
        onOpenLists: () => setState(() => _currentTab = 1),
      ),
      _ListsPage(
        lists: _lists,
        loading: _loading,
        onOpenList: (list) => _openFlow(list, reviewOnly: true),
        onDeleteList: _deleteList,
      ),
      _ExportLayoutPage(repository: widget.repository),
      _SettingsPage(
        repository: widget.repository,
        retentionDays: _retentionDays,
        onChangeRetention: _changeRetention,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: pages[_currentTab],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Listas',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'Layout',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.lists,
    required this.loading,
    required this.retentionDays,
    required this.onNewList,
    required this.onOpenLists,
  });

  final List<DeliveryList> lists;
  final bool loading;
  final int retentionDays;
  final VoidCallback onNewList;
  final VoidCallback onOpenLists;

  @override
  Widget build(BuildContext context) {
    final totalItems = lists.fold<int>(
      0,
      (sum, list) => sum + list.items.length,
    );
    final pending = lists.fold<int>(
      0,
      (sum, list) =>
          sum +
          list.items.where((item) {
            final name = item.name?.trim() ?? '';
            return name.isEmpty || item.status == ParcelStatus.needsReview;
          }).length,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Row(
          children: [
            Image.asset('assets/branding/app_icon.png', width: 46, height: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Estafeta',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _StartCard(onNewList: onNewList),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.inventory_2_outlined,
                label: 'Itens',
                value: loading ? '...' : '$totalItems',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.warning_amber_outlined,
                label: 'Revisar',
                value: loading ? '...' : '$pending',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.auto_delete_outlined,
                label: 'Fotos',
                value: '${retentionDays}d',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Recentes',
          action: lists.isEmpty ? null : 'Ver listas',
          onTap: onOpenLists,
        ),
        const SizedBox(height: 8),
        if (lists.isEmpty)
          const _EmptyCard(text: 'Crie a primeira lista para começar.')
        else
          ...lists
              .take(3)
              .map(
                (list) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(list.title),
                    subtitle: Text(
                      '${_formatDateTime(list.createdAt)} · ${list.items.length} encomendas',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onOpenLists,
                  ),
                ),
              ),
      ],
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.onNewList});

  final VoidCallback onNewList;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onNewList,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xff0d2c3d), Color(0xff113a3a)],
          ),
          border: Border.all(color: scheme.primary.withValues(alpha: .32)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: scheme.primary,
              foregroundColor: Colors.black,
              child: const Icon(Icons.add_a_photo_outlined, size: 30),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nova lista',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text('Abrir câmera e capturar etiquetas.'),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.secondary),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ListsPage extends StatelessWidget {
  const _ListsPage({
    required this.lists,
    required this.loading,
    required this.onOpenList,
    required this.onDeleteList,
  });

  final List<DeliveryList> lists;
  final bool loading;
  final ValueChanged<DeliveryList> onOpenList;
  final ValueChanged<DeliveryList> onDeleteList;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          'Listas',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (lists.isEmpty)
          const _EmptyCard(text: 'Nenhuma lista criada.')
        else
          ...lists.map((list) {
            final pending = list.items.where((item) {
              final name = item.name?.trim() ?? '';
              return name.isEmpty || item.status == ParcelStatus.needsReview;
            }).length;
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.local_shipping_outlined),
                ),
                title: Text(list.title),
                subtitle: Text(
                  '${_formatDateTime(list.createdAt)} · '
                  '${list.items.length} encomenda${list.items.length == 1 ? '' : 's'}'
                  '${pending > 0 ? ' · $pending revisar' : ''}',
                ),
                onTap: () => onOpenList(list),
                trailing: IconButton(
                  tooltip: 'Excluir lista',
                  onPressed: () => onDeleteList(list),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ExportLayoutPage extends StatefulWidget {
  const _ExportLayoutPage({required this.repository});

  final LocalDeliveryRepository repository;

  @override
  State<_ExportLayoutPage> createState() => _ExportLayoutPageState();
}

class _ExportLayoutPageState extends State<_ExportLayoutPage> {
  final _controller = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _controller.text = await widget.repository.getExportTemplate();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          'Layout',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('Use {titulo}, {data} e {nomes}.'),
        const SizedBox(height: 14),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          TextField(
            controller: _controller,
            minLines: 7,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Modelo do texto'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar layout'),
          ),
          TextButton(
            onPressed: () => setState(
              () => _controller.text = ShareTemplateDefaults.standard,
            ),
            child: const Text('Restaurar padrão'),
          ),
        ],
      ],
    );
  }

  Future<void> _save() async {
    await widget.repository.setExportTemplate(_controller.text);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Layout salvo.')));
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.repository,
    required this.retentionDays,
    required this.onChangeRetention,
  });

  final LocalDeliveryRepository repository;
  final int retentionDays;
  final VoidCallback onChangeRetention;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          'Ajustes',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.auto_delete_outlined),
            title: const Text('Retenção das fotos'),
            subtitle: Text('$retentionDays dias'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onChangeRetention,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Nomes conhecidos'),
            subtitle: const Text('Editar base usada pelo OCR'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => KnownNamesScreen(repository: repository),
              ),
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Processamento local'),
            subtitle: Text('OCR e fotos ficam no aparelho.'),
          ),
        ),
      ],
    );
  }
}

class KnownNamesScreen extends StatefulWidget {
  const KnownNamesScreen({super.key, required this.repository});

  final LocalDeliveryRepository repository;

  @override
  State<KnownNamesScreen> createState() => _KnownNamesScreenState();
}

class _KnownNamesScreenState extends State<KnownNamesScreen> {
  final _controller = TextEditingController();
  List<String> _names = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final names = await widget.repository.loadKnownNames();
    if (!mounted) return;
    setState(() {
      _names = names;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await widget.repository.saveKnownNames(_names);
  }

  Future<void> _add() async {
    final value = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return;
    if (!_names.any((name) => name.toLowerCase() == value.toLowerCase())) {
      setState(() => _names = [..._names, value]..sort());
      await _save();
    }
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nomes conhecidos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_names.isEmpty)
                  const _EmptyCard(text: 'Nenhum nome salvo ainda.')
                else
                  ..._names.map(
                    (name) => Card(
                      child: ListTile(
                        title: Text(name),
                        trailing: IconButton(
                          onPressed: () async {
                            setState(() {
                              _names = _names
                                  .where((item) => item != name)
                                  .toList();
                            });
                            await _save();
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(text)),
    );
  }
}

class _ListTypePicker extends StatefulWidget {
  const _ListTypePicker({required this.presets});
  final List<String> presets;

  @override
  State<_ListTypePicker> createState() => _ListTypePickerState();
}

class _ListTypePickerState extends State<_ListTypePicker> {
  bool _custom = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tipo de entrega',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...widget.presets.map(
              (title) => ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(title),
                onTap: () => Navigator.pop(context, title),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Personalizado'),
              onTap: () => setState(() => _custom = true),
            ),
            if (_custom) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (value) => value.trim().isEmpty
                    ? null
                    : Navigator.pop(context, value.trim()),
                decoration: const InputDecoration(labelText: 'Nome da lista'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (_controller.text.trim().isNotEmpty) {
                    Navigator.pop(context, _controller.text.trim());
                  }
                },
                child: const Text('Iniciar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
