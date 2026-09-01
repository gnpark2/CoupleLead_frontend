class Anniversary {
  final int id;
  final String title;
  final String anniversaryDate;
  final String type;
  final String repeatType;
  final String? customTypeName;

  const Anniversary({
    required this.id,
    required this.title,
    required this.anniversaryDate,
    required this.type,
    required this.repeatType,
    this.customTypeName,
  });

  factory Anniversary.fromJson(
    Map<String, dynamic> json,
  ) {
    return Anniversary(
      id: json['id'] as int,
      title: json['title'] as String,
      anniversaryDate: json['anniversaryDate'] as String,
      type: json['type'] as String,
      repeatType: json['repeatType'] as String,
      customTypeName: json['customTypeName'] as String?,
    );
  }
}
