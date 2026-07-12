enum ParcelStatus { queued, processing, recognized, needsReview }

class ParcelItem {
  const ParcelItem({
    required this.id,
    required this.imagePath,
    required this.capturedAt,
    required this.expiresAt,
    this.cropPath,
    this.name,
    this.rawText = '',
    this.confidence = 0,
    this.status = ParcelStatus.queued,
  });

  final String id;
  final String imagePath;
  final String? cropPath;
  final DateTime capturedAt;
  final DateTime expiresAt;
  final String? name;
  final String rawText;
  final double confidence;
  final ParcelStatus status;

  ParcelItem copyWith({
    String? cropPath,
    String? name,
    String? rawText,
    double? confidence,
    ParcelStatus? status,
  }) => ParcelItem(
    id: id,
    imagePath: imagePath,
    cropPath: cropPath ?? this.cropPath,
    capturedAt: capturedAt,
    expiresAt: expiresAt,
    name: name ?? this.name,
    rawText: rawText ?? this.rawText,
    confidence: confidence ?? this.confidence,
    status: status ?? this.status,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'cropPath': cropPath,
    'capturedAt': capturedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'name': name,
    'rawText': rawText,
    'confidence': confidence,
    'status': status.name,
  };

  factory ParcelItem.fromJson(Map<String, Object?> json) => ParcelItem(
    id: json['id']! as String,
    imagePath: json['imagePath']! as String,
    cropPath: json['cropPath'] as String?,
    capturedAt: DateTime.parse(json['capturedAt']! as String),
    expiresAt: DateTime.parse(json['expiresAt']! as String),
    name: json['name'] as String?,
    rawText: json['rawText'] as String? ?? '',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    status: ParcelStatus.values.byName(
      json['status'] as String? ?? ParcelStatus.needsReview.name,
    ),
  );
}

class DeliveryList {
  const DeliveryList({
    required this.id,
    required this.title,
    required this.createdAt,
    this.items = const [],
    this.completedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<ParcelItem> items;

  DeliveryList copyWith({List<ParcelItem>? items, DateTime? completedAt}) =>
      DeliveryList(
        id: id,
        title: title,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
        items: items ?? this.items,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory DeliveryList.fromJson(Map<String, Object?> json) => DeliveryList(
    id: json['id']! as String,
    title: json['title']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt']! as String),
    items: (json['items'] as List<Object?>? ?? const [])
        .map((item) => ParcelItem.fromJson(item! as Map<String, Object?>))
        .toList(),
  );
}
