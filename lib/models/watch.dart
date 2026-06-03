class WatchFields {
  static final List<String> values = [
    id, domainId, name, url, intervalMinutes, expectedStatus, keyword, lastStatus, lastCheckTime, isActive, consecutiveFails, latencyThreshold, alertOnSslExpiry, checkKeywordAbsence, httpMethod, httpHeaders, httpBody
  ];

  static const String id = 'id';
  static const String domainId = 'domainId';
  static const String name = 'name';
  static const String url = 'url';
  static const String intervalMinutes = 'intervalMinutes';
  static const String expectedStatus = 'expectedStatus';
  static const String keyword = 'keyword';
  static const String lastStatus = 'lastStatus';
  static const String lastCheckTime = 'lastCheckTime';
  static const String isActive = 'isActive';
  static const String consecutiveFails = 'consecutiveFails';
  static const String latencyThreshold = 'latencyThreshold';
  static const String alertOnSslExpiry = 'alertOnSslExpiry';
  static const String checkKeywordAbsence = 'checkKeywordAbsence';
  static const String httpMethod = 'httpMethod';
  static const String httpHeaders = 'httpHeaders';
  static const String httpBody = 'httpBody';
}

class Watch {
  final int? id;
  final int domainId;
  final String name;
  final String url;
  final int intervalMinutes;
  final int expectedStatus;
  final String? keyword;
  final int? lastStatus;
  final DateTime? lastCheckTime;
  final bool isActive;
  final int consecutiveFails;
  final int? latencyThreshold;
  final bool alertOnSslExpiry;
  final bool checkKeywordAbsence;
  final String httpMethod;
  final String? httpHeaders;
  final String? httpBody;

  const Watch({
    this.id,
    required this.domainId,
    required this.name,
    required this.url,
    required this.intervalMinutes,
    required this.expectedStatus,
    this.keyword,
    this.lastStatus,
    this.lastCheckTime,
    this.isActive = true,
    this.consecutiveFails = 0,
    this.latencyThreshold,
    this.alertOnSslExpiry = false,
    this.checkKeywordAbsence = false,
    this.httpMethod = 'HEAD',
    this.httpHeaders,
    this.httpBody,
  });

  Watch copyWith({
    int? id,
    int? domainId,
    String? name,
    String? url,
    int? intervalMinutes,
    int? expectedStatus,
    String? keyword,
    int? lastStatus,
    DateTime? lastCheckTime,
    bool? isActive,
    int? consecutiveFails,
    int? latencyThreshold,
    bool? alertOnSslExpiry,
    bool? checkKeywordAbsence,
    String? httpMethod,
    String? httpHeaders,
    String? httpBody,
  }) {
    return Watch(
      id: id ?? this.id,
      domainId: domainId ?? this.domainId,
      name: name ?? this.name,
      url: url ?? this.url,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      expectedStatus: expectedStatus ?? this.expectedStatus,
      keyword: keyword ?? this.keyword,
      lastStatus: lastStatus ?? this.lastStatus,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      isActive: isActive ?? this.isActive,
      consecutiveFails: consecutiveFails ?? this.consecutiveFails,
      latencyThreshold: latencyThreshold ?? this.latencyThreshold,
      alertOnSslExpiry: alertOnSslExpiry ?? this.alertOnSslExpiry,
      checkKeywordAbsence: checkKeywordAbsence ?? this.checkKeywordAbsence,
      httpMethod: httpMethod ?? this.httpMethod,
      httpHeaders: httpHeaders ?? this.httpHeaders,
      httpBody: httpBody ?? this.httpBody,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      WatchFields.id: id,
      WatchFields.domainId: domainId,
      WatchFields.name: name,
      WatchFields.url: url,
      WatchFields.intervalMinutes: intervalMinutes,
      WatchFields.expectedStatus: expectedStatus,
      WatchFields.keyword: keyword,
      WatchFields.lastStatus: lastStatus,
      WatchFields.lastCheckTime: lastCheckTime?.toIso8601String(),
      WatchFields.isActive: isActive ? 1 : 0,
      WatchFields.consecutiveFails: consecutiveFails,
      WatchFields.latencyThreshold: latencyThreshold,
      WatchFields.alertOnSslExpiry: alertOnSslExpiry ? 1 : 0,
      WatchFields.checkKeywordAbsence: checkKeywordAbsence ? 1 : 0,
      WatchFields.httpMethod: httpMethod,
      WatchFields.httpHeaders: httpHeaders,
      WatchFields.httpBody: httpBody,
    };
  }

  static Watch fromMap(Map<String, dynamic> map) {
    return Watch(
      id: map[WatchFields.id] as int?,
      domainId: map[WatchFields.domainId] as int,
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
      consecutiveFails: map[WatchFields.consecutiveFails] as int? ?? 0,
      latencyThreshold: map[WatchFields.latencyThreshold] as int?,
      alertOnSslExpiry: map[WatchFields.alertOnSslExpiry] == 1,
      checkKeywordAbsence: map[WatchFields.checkKeywordAbsence] == 1,
      httpMethod: map[WatchFields.httpMethod] as String? ?? 'HEAD',
      httpHeaders: map[WatchFields.httpHeaders] as String?,
      httpBody: map[WatchFields.httpBody] as String?,
    );
  }
}
