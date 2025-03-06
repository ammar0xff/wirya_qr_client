import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';

  Future<void> _login() async {
    String username = _usernameController.text;
    String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both username and password.';
      });
      return;
    }

    try {
      DatabaseReference usersRef = FirebaseDatabase.instance.ref("users");
      DatabaseEvent event = await usersRef.child(username).once();
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> user = event.snapshot.value as Map<dynamic, dynamic>;
        if (user["password"] == password) {
          _saveUserCredentials(username, password);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreen(user: username)),
          );
        } else {
          setState(() {
            _errorMessage = 'Invalid username or password.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid username or password.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _saveUserCredentials(String username, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setString('password', password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("تسجيل الدخول")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: "اسم المستخدم"),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: "كلمة المرور"),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text("تسجيل الدخول"),
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
