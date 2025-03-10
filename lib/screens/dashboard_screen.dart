import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DashboardScreen extends StatefulWidget {
  final String user;

  DashboardScreen({required this.user});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isLoading = false;
  String errorMessage = "";
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  List<Map<String, dynamic>> undoneTasks = [];
  List<Map<String, dynamic>> doneTasks = [];
  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      await _fetchTasks();
      await _fetchCurrentLocation();
    } catch (e) {
      setState(() {
        errorMessage = "Failed to fetch data: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchTasks() async {
    try {
      DatabaseReference tasksRef = FirebaseDatabase.instance.ref("users/${widget.user}/tasks");
      DatabaseEvent event = await tasksRef.once();
      if (event.snapshot.value != null) {
        // Convert Firebase data to Map<String, dynamic>
        Map<dynamic, dynamic> rawTasks = event.snapshot.value as Map<dynamic, dynamic>;
        Map<String, dynamic> tasks = Map<String, dynamic>.from(rawTasks);

        setState(() {
          undoneTasks = tasks.entries
              .where((entry) => entry.value['done'] == false)
              .map((entry) => entry.value as Map<String, dynamic>)
              .toList();
          doneTasks = tasks.entries
              .where((entry) => entry.value['done'] == true)
              .map((entry) => entry.value as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (e) {
      throw Exception("Failed to fetch tasks: $e");
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      DatabaseReference locationRef = FirebaseDatabase.instance.ref("users/${widget.user}/current_location");
      DatabaseEvent event = await locationRef.once();
      if (event.snapshot.value != null) {
        // Convert Firebase data to Map<String, dynamic>
        Map<dynamic, dynamic> rawLocation = event.snapshot.value as Map<dynamic, dynamic>;
        Map<String, dynamic> location = Map<String, dynamic>.from(rawLocation);

        setState(() {
          currentLocation = LatLng(
            double.parse(location['latitude'].toString()),
            double.parse(location['longitude'].toString()),
          );
        });
      }
    } catch (e) {
      throw Exception("Failed to fetch location: $e");
    }
  }

  void _onRefresh() async {
    await _fetchData();
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage, style: TextStyle(color: Colors.red)))
              : SmartRefresher(
                  controller: _refreshController,
                  onRefresh: _onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.all(8.0),
                    children: [
                      if (currentLocation != null)
                        Container(
                          height: 200,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: currentLocation!,
                              initialZoom: 13.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                subdomains: ['a', 'b', 'c'],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    width: 80.0,
                                    height: 80.0,
                                    point: currentLocation!,
                                    child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      _buildTaskSection("Undone Tasks", undoneTasks, Icons.check_box_outline_blank),
                      _buildTaskSection("Done Tasks", doneTasks, Icons.check_box),
                      _buildSummarySection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTaskSection(String title, List<Map<String, dynamic>> tasks, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...tasks.map((task) => Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(task['name'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task['data'], style: TextStyle(fontSize: 14)),
                  SizedBox(height: 4),
                  Text("Number: ${task['number']}", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              trailing: Icon(icon, color: Colors.blue),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text("Total Tasks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              trailing: Text("${undoneTasks.length + doneTasks.length}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text("Undone Tasks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              trailing: Text("${undoneTasks.length}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text("Done Tasks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              trailing: Text("${doneTasks.length}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}