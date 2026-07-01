import 'package:flutter/material.dart';
import 'package:evoly/shared/widgets/evoly_navigation_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    this.showBottomNavigationBar = true,
    super.key,
  });

  final bool showBottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: const [
          SwitchListTile(
            value: true,
            onChanged: null,
            title: Text('每日计划提醒'),
            subtitle: Text('每天早上提醒今天要推进的目标'),
          ),
          ListTile(
            leading: Icon(Icons.notifications_outlined),
            title: Text('默认提醒时间'),
            subtitle: Text('08:30'),
          ),
          ListTile(
            leading: Icon(Icons.dark_mode_outlined),
            title: Text('主题'),
            subtitle: Text('跟随系统'),
          ),
        ],
      ),
      bottomNavigationBar: showBottomNavigationBar
          ? const EvolyNavigationBar(selectedIndex: 4)
          : null,
    );
  }
}
