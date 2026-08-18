import 'package:flutter/material.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres du profil')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Compte privé'),
            subtitle: const Text('Seuls vos abonnés peuvent voir vos posts'),
            value: false,
            onChanged: (value) {},
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Recevoir des notifications'),
            value: true,
            onChanged: (value) {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Thème'),
            trailing: const Text('Clair'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Langue'),
            trailing: const Text('Français'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help, color: Colors.blue),
            title: const Text('Aide'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.green),
            title: const Text('À propos'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
