import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Firebase Database package
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences package

class TasksScreen extends StatefulWidget {
  @override
  _TasksScreenState createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    if (username != null) {
      DatabaseReference tasksRef = FirebaseDatabase.instance.ref("users/$username/tasks");
      DatabaseEvent event = await tasksRef.once();
      if (event.snapshot.value != null) {
        setState(() {
          tasks = (Map<String, dynamic>.from(event.snapshot.value as Map).values.toList()).cast<Map<String, dynamic>>();
        });
      }
    }
  }

  void _onRefresh() async {
    await _fetchTasks();
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tasks"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        child: ListView(
          children: tasks.map((task) => Card(
            child: ListTile(
              title: Text(task['name']),
              subtitle: Text(task['data']),
              trailing: Icon(task['done'] ? Icons.check_box : Icons.check_box_outline_blank),
            ),
          )).toList(),
        ),
      ),
    );
  }
}
