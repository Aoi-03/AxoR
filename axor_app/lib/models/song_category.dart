/// Song Category Model
/// Represents user-defined or default song categories (Gym, Study, Drive, etc.)
class SongCategory {
  final String id;
  final String name;
  final String? iconName; // Material icon name for UI
  final String? colorHex; // Hex color for UI theming
  final DateTime createdAt;

  SongCategory({
    required this.id,
    required this.name,
    this.iconName,
    this.colorHex,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SongCategory.fromJson(Map<String, dynamic> json) {
    return SongCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Untitled',
      iconName: json['iconName'],
      colorHex: json['colorHex'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconName': iconName,
        'colorHex': colorHex,
        'createdAt': createdAt.toIso8601String(),
      };

  SongCategory copyWith({
    String? id,
    String? name,
    String? iconName,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return SongCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Default categories that ship with the app
  static List<SongCategory> get defaults => [
        SongCategory(
          id: 'cat_gym',
          name: 'Gym',
          iconName: 'fitness_center',
          colorHex: '#FF3D3D',
        ),
        SongCategory(
          id: 'cat_study',
          name: 'Study',
          iconName: 'auto_stories',
          colorHex: '#00E5FF',
        ),
        SongCategory(
          id: 'cat_drive',
          name: 'Drive',
          iconName: 'directions_car',
          colorHex: '#00E676',
        ),
        SongCategory(
          id: 'cat_general',
          name: 'General',
          iconName: 'music_note',
          colorHex: '#7C4DFF',
        ),
      ];
}

/// Song-Category Mapping
/// Links a song to one or more categories
class SongCategoryMapping {
  final String songId;
  final String categoryId;

  SongCategoryMapping({
    required this.songId,
    required this.categoryId,
  });

  factory SongCategoryMapping.fromJson(Map<String, dynamic> json) {
    return SongCategoryMapping(
      songId: json['songId'] ?? '',
      categoryId: json['categoryId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'categoryId': categoryId,
      };
}

/// Cache Entry Model
/// Tracks cached artwork, metadata, and downloaded content
class CacheEntry {
  final String id;
  final String cacheType;   // 'artwork', 'metadata', 'audio'
  final String sourceKey;   // The URL or file ID this cache entry is for
  final String localPath;   // Path to cached file on disk
  final int sizeBytes;
  final DateTime lastAccessedAt;
  final DateTime createdAt;

  CacheEntry({
    required this.id,
    required this.cacheType,
    required this.sourceKey,
    required this.localPath,
    required this.sizeBytes,
    DateTime? lastAccessedAt,
    DateTime? createdAt,
  })  : lastAccessedAt = lastAccessedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      id: json['id'] ?? '',
      cacheType: json['cacheType'] ?? 'unknown',
      sourceKey: json['sourceKey'] ?? '',
      localPath: json['localPath'] ?? '',
      sizeBytes: json['sizeBytes'] ?? 0,
      lastAccessedAt: json['lastAccessedAt'] != null
          ? DateTime.tryParse(json['lastAccessedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cacheType': cacheType,
        'sourceKey': sourceKey,
        'localPath': localPath,
        'sizeBytes': sizeBytes,
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Song Feature Model
/// Tracks computed audio features for similarity search
class SongFeature {
  final String songId;
  final String featureType; // 'embedding', 'tempo', 'spectral', etc.
  final String modelVersion;
  final String featureReference; // Path to feature file or inline value
  final DateTime computedAt;

  SongFeature({
    required this.songId,
    required this.featureType,
    required this.modelVersion,
    required this.featureReference,
    DateTime? computedAt,
  }) : computedAt = computedAt ?? DateTime.now();

  factory SongFeature.fromJson(Map<String, dynamic> json) {
    return SongFeature(
      songId: json['songId'] ?? '',
      featureType: json['featureType'] ?? '',
      modelVersion: json['modelVersion'] ?? '',
      featureReference: json['featureReference'] ?? '',
      computedAt: json['computedAt'] != null
          ? DateTime.tryParse(json['computedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'featureType': featureType,
        'modelVersion': modelVersion,
        'featureReference': featureReference,
        'computedAt': computedAt.toIso8601String(),
      };
}
