import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DashboardScreen extends StatefulWidget {
  final String user;

  const DashboardScreen({Key? key, required this.user}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  List<Map<String, dynamic>> undoneTasks = [];
  List<Map<String, dynamic>> doneTasks = [];
  LatLng? currentLocation;
  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      await _fetchTasks();
      await _fetchCurrentLocation();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchTasks() async {
    try {
      final tasksRef = FirebaseDatabase.instance.ref("users/${widget.user}/tasks");
      final event = await tasksRef.once();

      if (event.snapshot.value != null) {
        final rawTasks = event.snapshot.value as Map<dynamic, dynamic>;
        final tasks = rawTasks.map((key, value) => MapEntry(key.toString(), value as Map<String, dynamic>));

        setState(() {
          undoneTasks = tasks.values.where((task) => task['done'] == false).toList();
          doneTasks = tasks.values.where((task) => task['done'] == true).toList();
        });
      }
    } catch (e) {
      throw Exception('Failed to fetch tasks: $e');
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final locationRef = FirebaseDatabase.instance.ref("users/${widget.user}/current_location");
      final event = await locationRef.once();

      if (event.snapshot.value != null) {
        final rawLocation = event.snapshot.value as Map<dynamic, dynamic>;
        final location = rawLocation.map((key, value) => MapEntry(key.toString(), value));

        setState(() {
          currentLocation = LatLng(
            double.parse(location['latitude'].toString()),
            double.parse(location['longitude'].toString()),
          );
        });
      }
    } catch (e) {
      throw Exception('Failed to fetch location: $e');
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
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red)));
    }

    return SmartRefresher(
      controller: _refreshController,
      onRefresh: _onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          if (currentLocation != null) _buildMap(),
          _buildTaskSection('Undone Tasks', undoneTasks, Icons.check_box_outline_blank),
          _buildTaskSection('Done Tasks', doneTasks, Icons.check_box),
          _buildSummarySection(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      height: 200,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: currentLocation!,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 80.0,
                height: 80.0,
                point: currentLocation!,
                child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSection(String title, List<Map<String, dynamic>> tasks, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...tasks.map((task) => Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(task['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task['data'], style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Number: ${task['number']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
          const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: const Text('Total Tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              trailing: Text('${undoneTasks.length + doneTasks.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: const Text('Undone Tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              trailing: Text('${undoneTasks.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: const Text('Done Tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              trailing: Text('${doneTasks.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}