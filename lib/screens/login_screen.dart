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
  String errorMessage = "";

  Future<void> _login() async {
    try {
      DatabaseReference usersRef = FirebaseDatabase.instance.ref("users");
      DatabaseEvent event = await usersRef.child(_usernameController.text).once();
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> user = event.snapshot.value as Map<dynamic, dynamic>;
        if (user["password"] == _passwordController.text) {
          _saveUserCredentials(_usernameController.text, _passwordController.text);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreen(user: _usernameController.text)),
          );
        } else {
          setState(() {
            errorMessage = "اسم المستخدم أو كلمة المرور غير صحيحة.";
          });
        }
      } else {
        setState(() {
          errorMessage = "اسم المستخدم أو كلمة المرور غير صحيحة.";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
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
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
