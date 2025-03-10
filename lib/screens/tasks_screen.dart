import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasksScreen extends StatefulWidget {
  @override
  _TasksScreenState createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  List<Map<String, dynamic>> tasks = [];
  bool isLoading = false;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('username');
      if (username != null) {
        DatabaseReference tasksRef = FirebaseDatabase.instance.ref("users/$username/tasks");
        DatabaseEvent event = await tasksRef.once();
        if (event.snapshot.value != null) {
          // Convert Firebase data to Map<String, dynamic>
          Map<dynamic, dynamic> rawTasks = event.snapshot.value as Map<dynamic, dynamic>;
          Map<String, dynamic> tasksMap = Map<String, dynamic>.from(rawTasks);

          setState(() {
            tasks = tasksMap.entries
                .map((entry) => entry.value as Map<String, dynamic>)
                .toList();
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to fetch tasks: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onRefresh() async {
    await _fetchTasks();
    _refreshController.refreshCompleted();
  }

  Future<void> _toggleTaskCompletion(String taskId, bool isDone) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    if (username != null) {
      DatabaseReference taskRef = FirebaseDatabase.instance.ref("users/$username/tasks/$taskId");
      await taskRef.update({'done': !isDone});
      await _fetchTasks();
    }
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
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage, style: TextStyle(color: Colors.red)))
              : tasks.isEmpty
                  ? Center(child: Text("No tasks found", style: TextStyle(fontSize: 16)))
                  : SmartRefresher(
                      controller: _refreshController,
                      onRefresh: _onRefresh,
                      child: ListView(
                        padding: const EdgeInsets.all(8.0),
                        children: tasks.map((task) => Card(
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
                            trailing: IconButton(
                              icon: Icon(task['done'] ? Icons.check_box : Icons.check_box_outline_blank, color: Colors.blue),
                              onPressed: () => _toggleTaskCompletion(task['id'], task['done']),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
    );
  }
}