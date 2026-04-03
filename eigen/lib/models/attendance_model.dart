class AttendanceModel {
  final String id;
  final String name;
  final String status;

  AttendanceModel({required this.id, required this.name, required this.status});

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    String extractedName = 'Unknown Student';

    // THE FIX: Safely check if 'user' is actually a Map to prevent NoSuchMethodError
    if (json['user'] is Map<String, dynamic>) {
      extractedName = json['user']['name'] ?? 'Unknown Student';
    } else if (json['name'] != null) {
      extractedName = json['name'];
    }

    return AttendanceModel(
      id: json['_id'] ?? '',
      name: extractedName,
      status: json['status'] ?? 'REGISTERED',
    );
  }
}