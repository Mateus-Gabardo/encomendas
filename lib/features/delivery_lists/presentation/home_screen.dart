import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
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

String _formatMonth(DateTime value) {
  const months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return '${months[value.month - 1]} ${value.year}';
}

String _formatRetentionDays(int days) => switch (days) {
  0 => 'Manter permanentemente',
  1 => '1 dia',
  _ => '$days dias',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final LocalDeliveryRepository repository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DeliveryList> _lists = const [];
  int _retentionDays = 14;
  int _knownNamesCount = 0;
  bool _loading = true;
  int _currentTab = 0;
  _ListFilter _listFilter = _ListFilter.all;

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
    final knownNames = await widget.repository.loadKnownNames();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _retentionDays = retention;
      _knownNamesCount = knownNames.length;
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
      builder: (context) => _RetentionDialog(initialDays: _retentionDays),
    );
    if (selected == null) return;
    await widget.repository.setRetentionDays(selected);
    if (mounted) setState(() => _retentionDays = selected);
  }

  void _openLists({_ListFilter filter = _ListFilter.all}) {
    setState(() {
      _listFilter = filter;
      _currentTab = 1;
    });
  }

  void _openKnownNames() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => KnownNamesScreen(repository: widget.repository),
      ),
    ).then((_) => _load());
  }

  void _openMetricsPanel() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MetricsPanelScreen(lists: _lists),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeDashboard(
        lists: _lists,
        loading: _loading,
        knownNamesCount: _knownNamesCount,
        onNewList: _newList,
        onOpenList: (list) => _openFlow(list, reviewOnly: true),
        onOpenLists: () => _openLists(),
        onOpenPeople: _openKnownNames,
        onOpenSentLists: () => _openLists(filter: _ListFilter.sent),
        onOpenMetrics: _openMetricsPanel,
      ),
      _ListsPage(
        lists: _lists,
        loading: _loading,
        filter: _listFilter,
        onFilterChanged: (filter) => setState(() => _listFilter = filter),
        onOpenList: (list) => _openFlow(list, reviewOnly: true),
        onDeleteList: _deleteList,
      ),
      _ExportLayoutPage(repository: widget.repository),
      _SettingsPage(
        repository: widget.repository,
        retentionDays: _retentionDays,
        themeMode: widget.themeMode,
        onChangeRetention: _changeRetention,
        onThemeModeChanged: widget.onThemeModeChanged,
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

enum _ListFilter {
  all('Todas'),
  sent('Enviadas'),
  notSent('Não enviadas');

  const _ListFilter(this.label);

  final String label;
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.lists,
    required this.loading,
    required this.knownNamesCount,
    required this.onNewList,
    required this.onOpenList,
    required this.onOpenLists,
    required this.onOpenPeople,
    required this.onOpenSentLists,
    required this.onOpenMetrics,
  });

  final List<DeliveryList> lists;
  final bool loading;
  final int knownNamesCount;
  final VoidCallback onNewList;
  final ValueChanged<DeliveryList> onOpenList;
  final VoidCallback onOpenLists;
  final VoidCallback onOpenPeople;
  final VoidCallback onOpenSentLists;
  final VoidCallback onOpenMetrics;

  @override
  Widget build(BuildContext context) {
    final sentLists = lists.where((list) => list.isSent).length;
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
            IconButton.filledTonal(
              tooltip: 'Painel de métricas',
              onPressed: onOpenMetrics,
              icon: const Icon(Icons.insights_outlined),
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
                icon: Icons.badge_outlined,
                label: 'Pessoas',
                value: loading ? '...' : '$knownNamesCount',
                onTap: onOpenPeople,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.list_alt_outlined,
                label: 'Listas',
                value: loading ? '...' : '${lists.length}',
                onTap: onOpenLists,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.outgoing_mail,
                label: 'Enviadas',
                value: loading ? '...' : '$sentLists',
                onTap: onOpenSentLists,
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatDateTime(list.createdAt)} · '
                          '${list.items.length} encomendas',
                        ),
                        _SentStatusText(
                          sent: list.isSent,
                          label: list.sentStatusLabel,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpenList(list),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onNewList,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: dark
                ? const [Color(0xff0d2c3d), Color(0xff113a3a)]
                : const [Color(0xffb8eee5), Color(0xffffd4a3)],
          ),
          border: Border.all(
            color: dark
                ? scheme.primary.withValues(alpha: .32)
                : const Color(0xff1ba996).withValues(alpha: .55),
          ),
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
            Icon(Icons.arrow_forward_ios, size: 18, color: scheme.onSurface),
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
      ),
    );
  }
}

class _ListsPage extends StatelessWidget {
  const _ListsPage({
    required this.lists,
    required this.loading,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenList,
    required this.onDeleteList,
  });

  final List<DeliveryList> lists;
  final bool loading;
  final _ListFilter filter;
  final ValueChanged<_ListFilter> onFilterChanged;
  final ValueChanged<DeliveryList> onOpenList;
  final ValueChanged<DeliveryList> onDeleteList;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final filteredLists = switch (filter) {
      _ListFilter.all => lists,
      _ListFilter.sent => lists.where((list) => list.isSent).toList(),
      _ListFilter.notSent => lists.where((list) => !list.isSent).toList(),
    };
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _ListFilter.values
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item.label),
                      selected: filter == item,
                      onSelected: (_) => onFilterChanged(item),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (lists.isEmpty)
          const _EmptyCard(text: 'Nenhuma lista criada.')
        else if (filteredLists.isEmpty)
          _EmptyCard(text: 'Nenhuma lista em "${filter.label}".')
        else
          ...filteredLists.map((list) {
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.local_shipping_outlined),
                ),
                title: Text(list.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatDateTime(list.createdAt)} · '
                      '${list.items.length} encomenda${list.items.length == 1 ? '' : 's'}',
                    ),
                    _SentStatusText(
                      sent: list.isSent,
                      label: list.sentStatusLabel,
                    ),
                  ],
                ),
                onTap: () => onOpenList(list),
                trailing: IconButton(
                  tooltip: 'Excluir lista',
                  onPressed: () => onDeleteList(list),
                  icon: const Icon(Icons.delete_outline),
                ),
                isThreeLine: true,
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              ),
            );
          }),
      ],
    );
  }
}

class MetricsPanelScreen extends StatefulWidget {
  const MetricsPanelScreen({super.key, required this.lists});

  final List<DeliveryList> lists;

  @override
  State<MetricsPanelScreen> createState() => _MetricsPanelScreenState();
}

class _MetricsPanelScreenState extends State<MetricsPanelScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
  }

  void _selectMonth(DateTime month) {
    setState(() => _selectedMonth = DateTime(month.year, month.month));
  }

  @override
  Widget build(BuildContext context) {
    final availableMonths = _availableMonths(widget.lists, _selectedMonth);
    final monthLists = widget.lists
        .where(
          (list) =>
              list.createdAt.year == _selectedMonth.year &&
              list.createdAt.month == _selectedMonth.month,
        )
        .toList();
    final sentThisMonth = widget.lists
        .where(
          (list) =>
              list.sentAt != null &&
              list.sentAt!.year == _selectedMonth.year &&
              list.sentAt!.month == _selectedMonth.month,
        )
        .length;
    final totalItems = widget.lists.fold<int>(
      0,
      (total, list) => total + list.items.length,
    );
    final monthItems = monthLists.fold<int>(
      0,
      (total, list) => total + list.items.length,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Painel')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            'Resumo operacional',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Indicadores simples para acompanhar o volume sem sobrecarregar a tela inicial.',
          ),
          const SizedBox(height: 16),
          _MonthSelector(
            month: _selectedMonth,
            availableMonths: availableMonths,
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
            onSelected: _selectMonth,
          ),
          const SizedBox(height: 16),
          _MetricSummaryTile(
            icon: Icons.inventory_2_outlined,
            title: 'Encomendas registradas',
            value: '$totalItems',
            subtitle: '$monthItems neste mês',
          ),
          _MetricSummaryTile(
            icon: Icons.list_alt_outlined,
            title: 'Listas criadas',
            value: '${widget.lists.length}',
            subtitle: '${monthLists.length} neste mês',
          ),
          _MetricSummaryTile(
            icon: Icons.outgoing_mail,
            title: 'Listas enviadas',
            value: '${widget.lists.where((list) => list.isSent).length}',
            subtitle: '$sentThisMonth neste mês',
          ),
          const SizedBox(height: 12),
          _DeliveryTypeChart(month: _selectedMonth, lists: monthLists),
        ],
      ),
    );
  }

  List<DateTime> _availableMonths(List<DeliveryList> lists, DateTime selected) {
    final months = {
      DateTime(selected.year, selected.month),
      for (final list in lists)
        DateTime(list.createdAt.year, list.createdAt.month),
    }.toList()..sort((a, b) => b.compareTo(a));
    return months.take(8).toList();
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.availableMonths,
    required this.onPrevious,
    required this.onNext,
    required this.onSelected,
  });

  final DateTime month;
  final List<DateTime> availableMonths;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _formatMonth(month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final availableMonth in availableMonths)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_formatShortMonth(availableMonth)),
                        selected:
                            availableMonth.year == month.year &&
                            availableMonth.month == month.month,
                        onSelected: (_) => onSelected(availableMonth),
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

class _MetricSummaryTile extends StatelessWidget {
  const _MetricSummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _DeliveryTypeChart extends StatelessWidget {
  const _DeliveryTypeChart({required this.month, required this.lists});

  final DateTime month;
  final List<DeliveryList> lists;

  @override
  Widget build(BuildContext context) {
    final totalsByType = <String, int>{};
    final countsByDayAndType = <int, Map<String, int>>{};
    for (final list in lists) {
      totalsByType.update(
        list.title,
        (value) => value + list.items.length,
        ifAbsent: () => list.items.length,
      );
      countsByDayAndType
          .putIfAbsent(list.createdAt.day, () => <String, int>{})
          .update(
            list.title,
            (value) => value + list.items.length,
            ifAbsent: () => list.items.length,
          );
    }
    final entries =
        totalsByType.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final visibleEntries = entries.take(5).toList();
    final visibleTypes = visibleEntries.map((entry) => entry.key).toList();
    final maxValue = countsByDayAndType.values.fold<int>(0, (max, dayCounts) {
      for (final type in visibleTypes) {
        final value = dayCounts[type] ?? 0;
        if (value > max) max = value;
      }
      return max;
    });
    final colors = _chartColors(context);
    final daysWithData = countsByDayAndType.keys.toList()..sort();
    final chartWidth = daysWithData.length * (visibleTypes.length * 12 + 32);

    return _ChartCard(
      title: 'Encomendas por dia e tipo em ${_formatMonth(month)}',
      empty: entries.isEmpty,
      height: 380,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth < 360 ? 360 : chartWidth.toDouble(),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    groupsSpace: 14,
                    maxY: (maxValue == 0 ? 1 : maxValue * 1.2).toDouble(),
                    barGroups: [
                      for (final day in daysWithData)
                        BarChartGroupData(
                          x: day,
                          barsSpace: 3,
                          barRods: [
                            for (
                              var index = 0;
                              index < visibleTypes.length;
                              index++
                            )
                              BarChartRodData(
                                toY:
                                    (countsByDayAndType[day]?[visibleTypes[index]] ??
                                            0)
                                        .toDouble(),
                                width: 8,
                                borderRadius: BorderRadius.circular(3),
                                color: colors[index % colors.length],
                              ),
                          ],
                        ),
                    ],
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: .45),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          getTitlesWidget: (value, meta) {
                            if (value == 0 || value == maxValue) {
                              return Text(
                                value.toInt().toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final day = value.toInt();
                            if (daysWithData.contains(day)) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '$day',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final type = visibleTypes[rodIndex];
                          final value = rod.toY.toInt();
                          return BarTooltipItem(
                            'Dia ${group.x}\n$type\n$value encomenda${value == 1 ? '' : 's'}',
                            TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'O eixo X mostra apenas os dias com encomendas registradas.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (var index = 0; index < visibleEntries.length; index++)
                _ChartLegendItem(
                  color: colors[index % colors.length],
                  label: visibleEntries[index].key,
                  value: visibleEntries[index].value,
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _chartColors(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      const Color(0xfff59e0b),
      const Color(0xff6366f1),
      const Color(0xffef4444),
    ];
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($value)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

String _formatShortMonth(DateTime value) {
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return '${months[value.month - 1]}/${value.year.toString().substring(2)}';
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.empty,
    required this.child,
    this.height = 220,
  });

  final String title;
  final bool empty;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (empty)
              const _EmptyCard(text: 'Sem dados para este mês.')
            else
              SizedBox(height: height, child: child),
          ],
        ),
      ),
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

class _RetentionDialog extends StatefulWidget {
  const _RetentionDialog({required this.initialDays});

  final int initialDays;

  @override
  State<_RetentionDialog> createState() => _RetentionDialogState();
}

class _RetentionDialogState extends State<_RetentionDialog> {
  late bool _keepPermanently;
  late int _selectedDays;
  late final FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _keepPermanently = widget.initialDays == 0;
    _selectedDays = widget.initialDays == 0
        ? 14
        : widget.initialDays.clamp(1, 3650).toInt();
    _scrollController = FixedExtentScrollController(
      initialItem: _selectedDays - 1,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _save() {
    if (_keepPermanently) {
      Navigator.pop(context, 0);
      return;
    }
    Navigator.pop(context, _selectedDays);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Retenção das fotos'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('As fotos serão excluídas após o período selecionado.'),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: Opacity(
            opacity: _keepPermanently ? .45 : 1,
            child: IgnorePointer(
              ignoring: _keepPermanently,
              child: CupertinoPicker.builder(
                scrollController: _scrollController,
                itemExtent: 40,
                onSelectedItemChanged: (index) =>
                    setState(() => _selectedDays = index + 1),
                childCount: 3650,
                itemBuilder: (context, index) => Center(
                  child: Text('${index + 1} ${index == 0 ? 'dia' : 'dias'}'),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Manter fotos permanentemente'),
          value: _keepPermanently,
          onChanged: (value) => setState(() {
            _keepPermanently = value ?? false;
          }),
        ),
      ],
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

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.repository,
    required this.retentionDays,
    required this.themeMode,
    required this.onChangeRetention,
    required this.onThemeModeChanged,
  });

  final LocalDeliveryRepository repository;
  final int retentionDays;
  final ThemeMode themeMode;
  final VoidCallback onChangeRetention;
  final ValueChanged<ThemeMode> onThemeModeChanged;

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
          child: SwitchListTile(
            secondary: const Icon(Icons.contrast_outlined),
            title: const Text('Tema escuro'),
            subtitle: const Text('O tema claro é o padrão do app.'),
            value: themeMode == ThemeMode.dark,
            onChanged: (enabled) =>
                onThemeModeChanged(enabled ? ThemeMode.dark : ThemeMode.light),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.auto_delete_outlined),
            title: const Text('Retenção das fotos'),
            subtitle: Text(_formatRetentionDays(retentionDays)),
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

class _SentStatusText extends StatelessWidget {
  const _SentStatusText({required this.sent, required this.label});

  final bool sent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: sent ? const Color(0xff168a45) : const Color(0xffd97706),
          fontWeight: FontWeight.w600,
        ),
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
