import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../models/attendance_model.dart';
import '../models/team_model.dart';
import '../services/event_service.dart';
import 'qr_scanner_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final EventService _eventService = EventService();
  bool _isLoading = true;
  List<dynamic> _allAttendees = [];

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    setState(() => _isLoading = true);
    List<dynamic> liveData = await _eventService.fetchAttendees(widget.event.id);
    setState(() {
      _allAttendees = liveData;
      _isLoading = false;
    });
  }

  Future<void> _openScannerAndRefresh(String type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QRScannerScreen(event: widget.event, scanType: type)),
    );
    _loadAttendees();
  }

  @override
  Widget build(BuildContext context) {
    // Filter logic works for both Teams and Individuals because they both have a 'status' or 'teamStatus'
    final List<dynamic> inside = _allAttendees.where((s) => (s is TeamModel ? s.teamStatus : s.status) == 'IN').toList();
    final List<dynamic> outside = _allAttendees.where((s) => (s is TeamModel ? s.teamStatus : s.status) == 'OUT').toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.black,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: 'REGISTERED'), Tab(text: 'INSIDE'), Tab(text: 'EXITED')],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : TabBarView(
          children: [
            _buildList(_allAttendees),
            _buildList(inside),
            _buildList(outside),
          ],
        ),

        // SCANNER BUTTONS
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            border: Border(top: BorderSide(color: Colors.white24, width: 1)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openScannerAndRefresh('IN'),
                    icon: const Icon(Icons.login, color: Colors.white),
                    label: const Text('SCAN IN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openScannerAndRefresh('OUT'),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text('SCAN OUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Decides whether to draw a normal list or a team list
  Widget _buildList(List<dynamic> items) {
    if (items.isEmpty) return const Center(child: Text('No records found.', style: TextStyle(color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _loadAttendees,
      color: Colors.black,
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is TeamModel) {
            return _buildTeamCard(item);
          } else {
            return _buildIndividualTile(item as AttendanceModel);
          }
        },
      ),
    );
  }

  // The UI for an Individual Student
  Widget _buildIndividualTile(AttendanceModel student) {
    Color statusColor = student.status == 'IN' ? Colors.greenAccent : (student.status == 'OUT' ? Colors.redAccent : Colors.grey);
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.white12, child: Text(student.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
      title: Text(student.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      trailing: _statusBadge(student.status, statusColor),
    );
  }

  // The New UI for a Team
  Widget _buildTeamCard(TeamModel team) {
    Color teamStatusColor = team.teamStatus == 'IN' ? Colors.greenAccent : Colors.grey;

    return Card(
      color: Colors.grey.shade900,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white12, width: 1)),
      child: ExpansionTile(
        title: Text(team.teamName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text("Leader: ${team.leaderName}", style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
        trailing: _statusBadge(team.teamStatus, teamStatusColor),
        iconColor: Colors.white,
        collapsedIconColor: Colors.grey,
        children: team.members.map((member) {
          Color memberColor = member.status == 'IN' ? Colors.greenAccent : (member.status == 'OUT' ? Colors.redAccent : Colors.grey);
          bool isLeader = member.name == team.leaderName;

          return ListTile(
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            title: Row(
              children: [
                Text(member.name, style: const TextStyle(color: Colors.white70)),
                if (isLeader) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.star, color: Colors.amber, size: 14)),
              ],
            ),
            trailing: _statusBadge(member.status, memberColor),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}