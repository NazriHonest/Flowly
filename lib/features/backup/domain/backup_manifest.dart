class BackupManifest {
  const BackupManifest({
    required this.version,
    required this.createdAt,
    required this.includesReceipts,
  });
  final int version;
  final DateTime createdAt;
  final bool includesReceipts;
  Map<String, Object> toJson() => {
    'version': version,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'includesReceipts': includesReceipts,
  };
  factory BackupManifest.fromJson(Map<String, Object?> json) => BackupManifest(
    version: json['version'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    includesReceipts: json['includesReceipts'] as bool,
  );
}
