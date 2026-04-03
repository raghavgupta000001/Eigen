import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../models/attendance_model.dart';
import '../models/team_model.dart';
import '../services/event_service.dart';
import 'qr_scanner_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  // NEW: State variable to control the view! (This was missing)
  bool _isTeamView = true;

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

  Future<void> _generateAndSharePDF() async {
    final pdf = pw.Document();

    List<List<String>> tableData = [
      ['Name', 'Type / Team', 'Status']
    ];

    for (var item in _allAttendees) {
      if (item is TeamModel) {
        for (var member in item.members) {
          tableData.add([member.name, item.teamName, member.status]);
        }
      } else if (item is AttendanceModel) {
        tableData.add([item.name, 'Individual', item.status]);
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${widget.event.title} - Attendance Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Generated on: ${DateTime.now().toString().split('.')[0]}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: tableData.first,
                data: tableData.sublist(1),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                },
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${widget.event.title}_Attendance.pdf',
    );
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
    final List<dynamic> inside = _allAttendees.where((s) => (s is TeamModel ? s.teamStatus : s.status) == 'IN').toList();
    final List<dynamic> outside = _allAttendees.where((s) => (s is TeamModel ? s.teamStatus : s.status) == 'OUT').toList();

    // NEW: Check if we have team data (This was missing)
    bool hasTeamData = _allAttendees.isNotEmpty && _allAttendees.first is TeamModel;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.black,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              tooltip: 'Export PDF',
              onPressed: () {
                if (_allAttendees.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export!')));
                  return;
                }
                _generateAndSharePDF();
              },
            ),
            if (hasTeamData)
              IconButton(
                icon: Icon(_isTeamView ? Icons.person : Icons.groups, color: Colors.blueAccent),
                tooltip: 'Toggle View',
                onPressed: () {
                  setState(() {
                    _isTeamView = !_isTeamView;
                  });
                },
              )
          ],
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

  Widget _buildList(List<dynamic> items) {
    if (items.isEmpty) return const Center(child: Text('No records found.', style: TextStyle(color: Colors.grey)));

    // NEW: Flatten the team list if the user toggled to "Member View" (This was missing)
    List<dynamic> displayItems = items;
    if (!_isTeamView && items.first is TeamModel) {
      List<AttendanceModel> flattenedMembers = [];
      for (var team in items) {
        flattenedMembers.addAll((team as TeamModel).members);
      }
      displayItems = flattenedMembers;
    }

    return RefreshIndicator(
      onRefresh: _loadAttendees,
      color: Colors.black,
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final item = displayItems[index];
          if (item is TeamModel) {
            return _buildTeamCard(item);
          } else {
            return _buildIndividualTile(item as AttendanceModel);
          }
        },
      ),
    );
  }

  Widget _buildIndividualTile(AttendanceModel student) {
    Color statusColor = student.status == 'IN' ? Colors.greenAccent : (student.status == 'OUT' ? Colors.redAccent : Colors.grey);
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.white12, child: Text(student.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
      title: Text(student.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      trailing: _statusBadge(student.status, statusColor),
    );
  }

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