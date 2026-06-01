class WatchFields {
  static final List<String> values = [
    id, name, url, intervalMinutes, expectedStatus, keyword, lastStatus, lastCheckTime, isActive
  ];

  static const String id = 'id';
  static const String name = 'name';
  static const String url = 'url';
  static const String intervalMinutes = 'intervalMinutes';
  static const String expectedStatus = 'expectedStatus';
  static const String keyword = 'keyword';
  static const String lastStatus = 'lastStatus';
  static const String lastCheckTime = 'lastCheckTime';
  static const String isActive = 'isActive';
}

class Watch {
  final int? id;
  final String name;
  final String url;
  final int intervalMinutes;
  final int expectedStatus;
  final String? keyword;
  final int? lastStatus;
  final DateTime? lastCheckTime;
  final bool isActive;

  const Watch({
    this.id,
    required this.name,
    required this.url,
    required this.intervalMinutes,
    required this.expectedStatus,
    this.keyword,
    this.lastStatus,
    this.lastCheckTime,
    this.isActive = true,
  });

  Watch copyWith({
    int? id,
    String? name,
    String? url,
    int? intervalMinutes,
    int? expectedStatus,
    String? keyword,
    int? lastStatus,
    DateTime? lastCheckTime,
    bool? isActive,
  }) {
    return Watch(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      expectedStatus: expectedStatus ?? this.expectedStatus,
      keyword: keyword ?? this.keyword,
      lastStatus: lastStatus ?? this.lastStatus,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      WatchFields.id: id,
      WatchFields.name: name,
      WatchFields.url: url,
      WatchFields.intervalMinutes: intervalMinutes,
      WatchFields.expectedStatus: expectedStatus,
      WatchFields.keyword: keyword,
      WatchFields.lastStatus: lastStatus,
      WatchFields.lastCheckTime: lastCheckTime?.toIso8601String(),
      WatchFields.isActive: isActive ? 1 : 0,
    };
  }

  static Watch fromMap(Map<String, dynamic> map) {
    return Watch(
      id: map[WatchFields.id] as int?,
      name: map[WatchFields.name] as String,
      url: map[WatchFields.url] as String,
      intervalMinutes: map[WatchFields.intervalMinutes] as int,
      expectedStatus: map[WatchFields.expectedStatus] as int,
      keyword: map[WatchFields.keyword] as String?,
      lastStatus: map[WatchFields.lastStatus] as int?,
      lastCheckTime: map[WatchFields.lastCheckTime] != null
          ? DateTime.parse(map[WatchFields.lastCheckTime] as String)
          : null,
      isActive: map[WatchFields.isActive] == 1,
    );
  }
}
