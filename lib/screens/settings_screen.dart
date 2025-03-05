import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isBeepSoundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isBeepSoundEnabled = prefs.getBool('isBeepSoundEnabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBeepSoundEnabled', isBeepSoundEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("الإعدادات")),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text("تشغيل صوت التنبيه"),
            value: isBeepSoundEnabled,
            onChanged: (bool value) {
              setState(() {
                isBeepSoundEnabled = value;
                _saveSettings();
              });
            },
          ),
        ],
      ),
    );
  }
}
