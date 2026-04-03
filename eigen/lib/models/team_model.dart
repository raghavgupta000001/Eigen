import 'attendance_model.dart';

class TeamModel {
  final String id;
  final String teamName;
  final String leaderName;
  final String teamStatus;
  final List<AttendanceModel> members;

  TeamModel({
    required this.id,
    required this.teamName,
    required this.leaderName,
    required this.teamStatus,
    required this.members,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    var list = json['members'] as List? ?? [];

    // THE FIX: Explicitly cast 'i' to a Map so Dart doesn't panic
    List<AttendanceModel> membersList = list
        .map((i) => AttendanceModel.fromJson(i as Map<String, dynamic>))
        .toList();

    return TeamModel(
      id: json['_id'] ?? '',
      teamName: json['teamName'] ?? 'Unknown Team',
      leaderName: json['leaderName'] ?? 'Unknown',
      teamStatus: json['teamStatus'] ?? 'REGISTERED',
      members: membersList,
    );
  }
}