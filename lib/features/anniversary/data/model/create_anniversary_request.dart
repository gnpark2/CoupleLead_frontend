class CreateAnniversaryRequest {
  final String title;
  final String anniversaryDate;
  final String type;
  final String repeatType;
  final String? customTypeName;

  const CreateAnniversaryRequest({
    required this.title,
    required this.anniversaryDate,
    required this.type,
    required this.repeatType,
    this.customTypeName,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'anniversaryDate':
          anniversaryDate,
      'type': type,
      'repeatType':
          repeatType,
      'customTypeName':
          customTypeName,
    };
  }
}