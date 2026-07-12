import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/delivery_models.dart';

class LocalDeliveryRepository {
  Future<Directory> get _root async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}encomendas',
    );
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
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
            deleted++;
          }
        }
      }
    }
    return deleted;
  }
}
