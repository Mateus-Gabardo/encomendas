import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/delivery_models.dart';
import '../domain/share_formatter.dart';

class LocalDeliveryRepository {
  Future<Directory> get _root async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}estafeta',
    );
    final legacyDirectory = Directory(
      '${documents.path}${Platform.pathSeparator}encomendas',
    );
    if (!await directory.exists() && await legacyDirectory.exists()) {
      await legacyDirectory.rename(directory.path);
    }
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _databaseFile() async =>
      File('${(await _root).path}${Platform.pathSeparator}lists.json');

  Future<List<DeliveryList>> loadLists() async {
    final file = await _databaseFile();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString()) as List<Object?>;
      return decoded
          .map((item) => DeliveryList.fromJson(item! as Map<String, Object?>))
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> saveList(DeliveryList updated) async {
    final lists = await loadLists();
    final index = lists.indexWhere((list) => list.id == updated.id);
    if (index < 0) {
      lists.insert(0, updated);
    } else {
      lists[index] = updated;
    }
    await (await _databaseFile()).writeAsString(
      jsonEncode(lists.map((list) => list.toJson()).toList()),
      flush: true,
    );
  }

  Future<void> deleteList(String listId) async {
    final lists = await loadLists();
    final target = lists.where((list) => list.id == listId).firstOrNull;
    if (target != null) {
      for (final item in target.items) {
        for (final path in [item.imagePath, item.cropPath]) {
          if (path == null || path.isEmpty) continue;
          await deleteStoredFile(path);
        }
      }
    }
    final updated = lists.where((list) => list.id != listId).toList();
    await (await _databaseFile()).writeAsString(
      jsonEncode(updated.map((list) => list.toJson()).toList()),
      flush: true,
    );
    final photoDirectory = Directory(
      '${(await _root).path}${Platform.pathSeparator}photos${Platform.pathSeparator}$listId',
    );
    if (await photoDirectory.exists()) {
      await photoDirectory.delete(recursive: true);
    }
  }

  Future<String> retainPhoto({
    required String sourcePath,
    required String listId,
    required String itemId,
  }) async {
    final root = await _root;
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}photos${Platform.pathSeparator}$listId',
    );
    await directory.create(recursive: true);
    final destination = '${directory.path}${Platform.pathSeparator}$itemId.jpg';
    await File(sourcePath).copy(destination);
    return destination;
  }

  Future<void> deleteStoredFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<int> getRetentionDays() async {
    final file = File(
      '${(await _root).path}${Platform.pathSeparator}retention_days.txt',
    );
    if (!await file.exists()) return 14;
    return int.tryParse(await file.readAsString()) == 7 ? 7 : 14;
  }

  Future<void> setRetentionDays(int days) async {
    final value = days == 7 ? 7 : 14;
    final file = File(
      '${(await _root).path}${Platform.pathSeparator}retention_days.txt',
    );
    await file.writeAsString('$value', flush: true);
  }

  Future<File> _knownNamesFile() async =>
      File('${(await _root).path}${Platform.pathSeparator}known_names.json');

  Future<List<String>> loadKnownNames() async {
    final file = await _knownNamesFile();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString()) as List<Object?>;
      final names =
          decoded
              .whereType<String>()
              .map((name) => name.trim().replaceAll(RegExp(r'\s+'), ' '))
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return names;
    } on FormatException {
      return [];
    }
  }

  Future<void> saveKnownNames(List<String> names) async {
    final normalized =
        names
            .map((name) => name.trim().replaceAll(RegExp(r'\s+'), ' '))
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await (await _knownNamesFile()).writeAsString(
      jsonEncode(normalized),
      flush: true,
    );
  }

  Future<void> addKnownName(String name) async {
    final value = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return;
    final names = await loadKnownNames();
    if (!names.any((item) => item.toLowerCase() == value.toLowerCase())) {
      await saveKnownNames([...names, value]);
    }
  }

  Future<String> getExportTemplate() async {
    final file = File(
      '${(await _root).path}${Platform.pathSeparator}export_template.txt',
    );
    if (!await file.exists()) return ShareTemplateDefaults.standard;
    final value = await file.readAsString();
    return value.trim().isEmpty ? ShareTemplateDefaults.standard : value;
  }

  Future<void> setExportTemplate(String template) async {
    final value = template.trim().isEmpty
        ? ShareTemplateDefaults.standard
        : template;
    final file = File(
      '${(await _root).path}${Platform.pathSeparator}export_template.txt',
    );
    await file.writeAsString(value, flush: true);
  }

  Future<int> deleteExpiredPhotos() async {
    final lists = await loadLists();
    final now = DateTime.now();
    var deleted = 0;
    for (final list in lists) {
      for (final item in list.items.where(
        (item) => item.expiresAt.isBefore(now),
      )) {
        for (final path in [item.imagePath, item.cropPath]) {
          if (path == null || path.isEmpty) continue;
          if (await File(path).exists()) {
            await deleteStoredFile(path);
            deleted++;
          }
        }
      }
    }
    return deleted;
  }
}
