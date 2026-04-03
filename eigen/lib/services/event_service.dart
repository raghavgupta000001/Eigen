// lib/services/event_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/event_model.dart';
import '../models/attendance_model.dart';
import '../models/team_model.dart';

class EventService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Replace this with your live Render URL when testing on a real phone!
  final String baseUrl = 'https://eigen-hhcm.onrender.com/api/v1/events';

  Future<List<EventModel>> fetchMyEvents() async {
    try {
      // 1. Grab the VIP Wristband
      String? jwtToken = await _storage.read(key: 'jwt_token');

      if (jwtToken == null) throw Exception("No auth token found");

      // 2. Make the request to the backend
      final response = await http.get(
        Uri.parse('$baseUrl/my-club-events'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // 3. The backend sends an array of events inside the 'data' field
        final List<dynamic> eventsJson = responseData['data'];

        // 4. Convert the JSON list into a list of Dart Objects
        return eventsJson.map((json) => EventModel.fromJson(json)).toList();
      } else {
        print("Failed to load events: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Error fetching events: $e");
      return [];
    }
  }

  // --- UPDATED: Includes explicit Map casting and fallback logic ---
  Future<List<dynamic>> fetchAttendees(String eventId) async {
    try {
      String? jwtToken = await _storage.read(key: 'jwt_token');
      if (jwtToken == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/$eventId/attendees'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // This is the actual data sent back by the server
        final dynamic dataPayload = responseData['data'];

        // ========================================================
        // FALLBACK: If Rohit's code hasn't deployed to Render yet
        // ========================================================
        if (dataPayload is List) {
          print("⚠️ WARNING: Server is still using the OLD flat-list format!");
          return dataPayload.map((json) => AttendanceModel.fromJson(json as Map<String, dynamic>)).toList();
        }

        // ========================================================
        // NEW CODE: If the server sends the new structured Map
        // ========================================================
        if (dataPayload is Map) {
          final String type = dataPayload['type'] ?? 'INDIVIDUAL';
          final List<dynamic> recordsJson = dataPayload['data'] ?? [];

          if (type == 'TEAM') {
            return recordsJson.map((json) => TeamModel.fromJson(json as Map<String, dynamic>)).toList();
          } else {
            return recordsJson.map((json) => AttendanceModel.fromJson(json as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      // IF IT FAILS, THIS WILL TELL US EXACTLY WHY!
      print("🛑 CRITICAL PARSING ERROR: $e");
      return [];
    }
  }

  // --- UPDATED: Includes robust HTML error catching ---
  Future<String> submitScan(String eventId, String qrCode, String scanType) async {
    try {
      String? jwtToken = await _storage.read(key: 'jwt_token');
      if (jwtToken == null) return "Error: You are not logged in.";

      final response = await http.post(
        Uri.parse('$baseUrl/$eventId/scan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'qrCodeIdentifier': qrCode,
          'scanType': scanType, // 'IN' or 'OUT'
        }),
      );

      // 1. If Success, decode the JSON
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return "SUCCESS: ${responseData['message']}";
      }
      // 2. If Error, carefully check what the server sent back
      else {
        try {
          // Try to read it as JSON first
          final errorData = jsonDecode(response.body);
          return "ERROR: ${errorData['message'] ?? 'Scan Failed'}";
        } catch (_) {
          // THE FIX: If jsonDecode crashes, the server sent HTML!
          if (response.statusCode == 400) return "ERROR: Student is already marked $scanType.";
          if (response.statusCode == 403) return "ERROR: Access Denied. Student is NOT registered.";
          if (response.statusCode == 404) return "ERROR: Invalid QR. Student not found.";

          return "ERROR: Server rejected scan (Code: ${response.statusCode})";
        }
      }
    } catch (e) {
      return "ERROR: Network issue. Check internet connection.";
    }
  }
}