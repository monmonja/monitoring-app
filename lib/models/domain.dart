class DomainFields {
  static final List<String> values = [
    id, name, url
  ];

  static const String id = 'id';
  static const String name = 'name';
  static const String url = 'url';
}

class Domain {
  final int? id;
  final String name;
  final String url;

  const Domain({
    this.id,
    required this.name,
    required this.url,
  });

  Domain copyWith({
    int? id,
    String? name,
    String? url,
  }) {
    return Domain(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DomainFields.id: id,
      DomainFields.name: name,
      DomainFields.url: url,
    };
  }

  static Domain fromMap(Map<String, dynamic> map) {
    return Domain(
      id: map[DomainFields.id] as int?,
      name: map[DomainFields.name] as String,
      url: map[DomainFields.url] as String,
    );
  }
}
