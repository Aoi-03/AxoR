import '../services/api_config.dart';

/// Availability status for songs
enum SongAvailability {
  local,       // File is on device
  cloud,       // File is in cloud only
  downloaded,  // Downloaded from cloud for offline use
  unavailable, // Source no longer available
}

/// Download status for songs
enum SongDownloadStatus {
  none,        // Not downloaded
  downloading, // Currently downloading
  downloaded,  // Successfully downloaded
  failed,      // Download failed
}

/// Song Model
/// Represents a song from the backend or local library
class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final int bpm;
  final double energy;
  final String mood;
  final String genre;
  final String filePath;
  final String? coverPath;
  final int fileSize;
  final String format;
  final int sampleRate;
  final int bitrate;
  final int? year;
  final String? fileName;
  final double? similarity; // For AI similar songs
  final bool? cached; // Is song cached on backend
  final bool? caching; // Is song currently being cached
  final int? cachingProgress; // Caching progress (0-100)

  // ── New fields for local-first architecture ──
  final String? contentHash;         // SHA-256 of first 64KB for dedup
  final String? providerTrackId;     // Cloud provider file ID (e.g. Drive file ID)
  final SongAvailability availabilityStatus;
  final SongDownloadStatus downloadStatus;
  final String? artworkReference;    // Local artwork path or URL
  final String? localFilePath;       // Path to downloaded/local file
  final DateTime? metadataUpdatedAt;
  final List<String> categoryIds;    // Song category IDs

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.bpm,
    required this.energy,
    required this.mood,
    required this.genre,
    required this.filePath,
    this.coverPath,
    required this.fileSize,
    required this.format,
    required this.sampleRate,
    required this.bitrate,
    this.year,
    this.fileName,
    this.similarity,
    this.cached,
    this.caching,
    this.cachingProgress,
    this.contentHash,
    this.providerTrackId,
    this.availabilityStatus = SongAvailability.cloud,
    this.downloadStatus = SongDownloadStatus.none,
    this.artworkReference,
    this.localFilePath,
    this.metadataUpdatedAt,
    this.categoryIds = const [],
  });
  
  // Create Song from JSON
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? 'Unknown Album',
      duration: json['duration'] ?? 0,
      bpm: json['bpm'] ?? 120,
      energy: (json['energy'] ?? 0.5).toDouble(),
      mood: json['mood'] ?? 'neutral',
      genre: json['genre'] ?? 'Unknown',
      filePath: json['filePath'] ?? '',
      coverPath: json['coverPath'],
      fileSize: json['fileSize'] ?? 0,
      format: json['format'] ?? 'FLAC',
      sampleRate: json['sampleRate'] ?? 44100,
      bitrate: json['bitrate'] ?? 1411,
      year: json['year'],
      fileName: json['fileName'],
      similarity: json['similarity']?.toDouble(),
      cached: json['cached'] ?? false,
      caching: json['caching'] ?? false,
      cachingProgress: json['cachingProgress'] ?? 0,
      contentHash: json['contentHash'],
      providerTrackId: json['providerTrackId'],
      availabilityStatus: _parseAvailability(json['availabilityStatus']),
      downloadStatus: _parseDownloadStatus(json['downloadStatus']),
      artworkReference: json['artworkReference'],
      localFilePath: json['localFilePath'],
      metadataUpdatedAt: json['metadataUpdatedAt'] != null
          ? DateTime.tryParse(json['metadataUpdatedAt'])
          : null,
      categoryIds: List<String>.from(json['categoryIds'] ?? []),
    );
  }
  
  // Convert Song to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'bpm': bpm,
      'energy': energy,
      'mood': mood,
      'genre': genre,
      'filePath': filePath,
      'coverPath': coverPath,
      'fileSize': fileSize,
      'format': format,
      'sampleRate': sampleRate,
      'bitrate': bitrate,
      'year': year,
      'fileName': fileName,
      'similarity': similarity,
      'cached': cached,
      'caching': caching,
      'cachingProgress': cachingProgress,
      'contentHash': contentHash,
      'providerTrackId': providerTrackId,
      'availabilityStatus': availabilityStatus.name,
      'downloadStatus': downloadStatus.name,
      'artworkReference': artworkReference,
      'localFilePath': localFilePath,
      'metadataUpdatedAt': metadataUpdatedAt?.toIso8601String(),
      'categoryIds': categoryIds,
    };
  }

  /// Create a copy with updated fields
  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? duration,
    int? bpm,
    double? energy,
    String? mood,
    String? genre,
    String? filePath,
    String? coverPath,
    int? fileSize,
    String? format,
    int? sampleRate,
    int? bitrate,
    int? year,
    String? fileName,
    double? similarity,
    bool? cached,
    bool? caching,
    int? cachingProgress,
    String? contentHash,
    String? providerTrackId,
    SongAvailability? availabilityStatus,
    SongDownloadStatus? downloadStatus,
    String? artworkReference,
    String? localFilePath,
    DateTime? metadataUpdatedAt,
    List<String>? categoryIds,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      bpm: bpm ?? this.bpm,
      energy: energy ?? this.energy,
      mood: mood ?? this.mood,
      genre: genre ?? this.genre,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      fileSize: fileSize ?? this.fileSize,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      bitrate: bitrate ?? this.bitrate,
      year: year ?? this.year,
      fileName: fileName ?? this.fileName,
      similarity: similarity ?? this.similarity,
      cached: cached ?? this.cached,
      caching: caching ?? this.caching,
      cachingProgress: cachingProgress ?? this.cachingProgress,
      contentHash: contentHash ?? this.contentHash,
      providerTrackId: providerTrackId ?? this.providerTrackId,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      artworkReference: artworkReference ?? this.artworkReference,
      localFilePath: localFilePath ?? this.localFilePath,
      metadataUpdatedAt: metadataUpdatedAt ?? this.metadataUpdatedAt,
      categoryIds: categoryIds ?? this.categoryIds,
    );
  }
  
  // Get full streaming URL
  String get streamUrl => ApiConfig.getSongUrl(filePath);
  
  // Get cover art URL
  String get coverUrl => '${ApiConfig.baseUrl}/api/songs/cover/$id';
  
  // Check if has embedded cover
  bool get hasEmbeddedCover => coverPath == 'embedded';

  // Check if song is available locally
  bool get isLocal =>
      availabilityStatus == SongAvailability.local ||
      availabilityStatus == SongAvailability.downloaded;

  // Check if song can be played offline
  bool get isAvailableOffline =>
      isLocal && (localFilePath != null || filePath.isNotEmpty);
  
  // Format duration as MM:SS
  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Format file size as MB
  String get formattedFileSize {
    final mb = fileSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
  
  // Get energy level description
  String get energyLevel {
    if (energy >= 0.8) return 'Very High';
    if (energy >= 0.6) return 'High';
    if (energy >= 0.4) return 'Medium';
    if (energy >= 0.2) return 'Low';
    return 'Very Low';
  }

  // ── Private helpers ──

  static SongAvailability _parseAvailability(String? value) {
    if (value == null) return SongAvailability.cloud;
    return SongAvailability.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SongAvailability.cloud,
    );
  }

  static SongDownloadStatus _parseDownloadStatus(String? value) {
    if (value == null) return SongDownloadStatus.none;
    return SongDownloadStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SongDownloadStatus.none,
    );
  }
}
