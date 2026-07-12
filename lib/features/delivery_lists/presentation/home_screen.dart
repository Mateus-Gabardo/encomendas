import 'package:flutter/material.dart';

import '../data/local_delivery_repository.dart';
import '../domain/delivery_models.dart';
import 'delivery_flow_screen.dart';

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
    if (mounted) {
      setState(() {
        _lists = lists;
        _retentionDays = retention;
        _loading = false;
      });
    }
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
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DeliveryFlowScreen(
          list: list,
          repository: widget.repository,
          retentionDays: _retentionDays,
        ),
      ),
    );
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
        onOpenList: _openList,
      ),
      _InsightsPage(lists: _lists),
      _SettingsPage(
        retentionDays: _retentionDays,
        onChangeRetention: _changeRetention,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
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
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Listas',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Resumo',
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

  Future<void> _openList(DeliveryList list) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DeliveryFlowScreen(
          list: list,
          repository: widget.repository,
          retentionDays: _retentionDays,
          reviewOnly: true,
        ),
      ),
    );
    await _load();
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
      (total, list) => total + list.items.length,
    );
    final pending = lists.fold<int>(
      0,
      (total, list) => total +
          list.items
              .where(
                (item) =>
                    item.status == ParcelStatus.needsReview ||
                    item.name == null ||
                    item.name!.trim().isEmpty,
              )
              .length,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          'Encomendas',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Capture etiquetas, confira nomes e compartilhe a lista pronta.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        _HeroCaptureCard(onNewList: onNewList),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                color: const Color(0xffffd166),
                icon: Icons.inventory_2_outlined,
                label: 'Encomendas',
                value: loading ? '...' : '$totalItems',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                color: const Color(0xffef476f),
                icon: Icons.fact_check_outlined,
                label: 'Pendentes',
                value: loading ? '...' : '$pending',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                color: const Color(0xff06d6a0),
                icon: Icons.playlist_add_check,
                label: 'Listas',
                value: loading ? '...' : '${lists.length}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                color: const Color(0xff118ab2),
                icon: Icons.auto_delete_outlined,
                label: 'Fotos',
                value: '$retentionDays dias',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.history)),
            title: const Text('Continuar uma lista existente'),
            subtitle: Text(
              lists.isEmpty
                  ? 'Nenhuma lista criada ainda'
                  : '${lists.length} lista${lists.length == 1 ? '' : 's'} disponiveis',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenLists,
          ),
        ),
      ],
    );
  }
}

class _HeroCaptureCard extends StatelessWidget {
  const _HeroCaptureCard({required this.onNewList});

  final VoidCallback onNewList;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primary,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              const Color(0xff06d6a0),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Nova rodada de entregas',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Abra a camera, fotografe em sequencia e revise os nomes sem sair do fluxo.',
              style: TextStyle(color: Colors.white, height: 1.35),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: scheme.primary,
                  ),
                  onPressed: onNewList,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Criar nova lista'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .18),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
  });

  final List<DeliveryList> lists;
  final bool loading;
  final ValueChanged<DeliveryList> onOpenList;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('Listas'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        if (lists.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nenhuma lista criada ainda.'),
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: lists.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final list = lists[index];
              final pending = list.items
                  .where(
                    (item) =>
                        item.status == ParcelStatus.needsReview ||
                        item.name == null ||
                        item.name!.trim().isEmpty,
                  )
                  .length;
              return Padding(
                padding: EdgeInsets.fromLTRB(16, index == 0 ? 8 : 0, 16, 0),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: const Icon(Icons.local_shipping_outlined),
                    ),
                    title: Text(list.title),
                    subtitle: Text(
                      '${list.items.length} encomenda${list.items.length == 1 ? '' : 's'}'
                      '${pending > 0 ? ' · $pending pendente${pending == 1 ? '' : 's'}' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpenList(list),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _InsightsPage extends StatelessWidget {
  const _InsightsPage({required this.lists});

  final List<DeliveryList> lists;

  @override
  Widget build(BuildContext context) {
    final lastList = lists.firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Resumo',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.bolt_outlined)),
            title: const Text('Ultima atividade'),
            subtitle: Text(
              lastList == null
                  ? 'Ainda nao ha capturas'
                  : '${lastList.title} com ${lastList.items.length} item${lastList.items.length == 1 ? '' : 's'}',
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.center_focus_strong)),
            title: Text('Proximo ajuste sugerido'),
            subtitle: Text(
              'Medir a velocidade do OCR no celular real para decidir se vale usar isolate dedicado.',
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.retentionDays,
    required this.onChangeRetention,
  });

  final int retentionDays;
  final VoidCallback onChangeRetention;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Ajustes',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.auto_delete_outlined)),
            title: const Text('Retencao das fotos'),
            subtitle: Text('As imagens expiram em $retentionDays dias'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onChangeRetention,
          ),
        ),
        const Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.security_outlined)),
            title: Text('OCR local'),
            subtitle: Text('As fotos sao processadas no aparelho.'),
          ),
        ),
      ],
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
              'Qual é o tipo de entrega?',
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
              title: const Text('Nome personalizado'),
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
                decoration: const InputDecoration(
                  labelText: 'Nome da lista',
                  border: OutlineInputBorder(),
                ),
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
