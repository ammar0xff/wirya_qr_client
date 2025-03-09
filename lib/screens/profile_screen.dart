import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error loading profile"));
          } else {
            final prefs = snapshot.data!;
            final username = prefs.getString('username') ?? 'Unknown';
            final email = prefs.getString('email') ?? 'Unknown';
            final phone = prefs.getString('phone') ?? 'Unknown';
            final location = prefs.getString('location') ?? 'Unknown';

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Name: $username", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Email: $email", style: TextStyle(fontSize: 16)),
                  Text("Phone: $phone", style: TextStyle(fontSize: 16)),
                  Text("Location: $location", style: TextStyle(fontSize: 16)),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to edit profile screen
                    },
                    child: Text("Edit Profile"),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
