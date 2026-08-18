import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_provider.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminProvider>().loadUsers(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => context.read<AdminProvider>().setSearchQuery(value),
            ),
          ),
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.users.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.users.isEmpty) {
                  return const Center(child: Text('Aucun utilisateur'));
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Nom')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Rôle')),
                      DataColumn(label: Text('Inscrit le')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: provider.users.map((user) => DataRow(cells: [
                      DataCell(Text(user['name'] ?? 'N/A')),
                      DataCell(Text(user['email'])),
                      DataCell(DropdownButton<String>(
                        value: user['role'],
                        items: const [
                          DropdownMenuItem(value: 'user', child: Text('Utilisateur')),
                          DropdownMenuItem(value: 'seller', child: Text('Vendeur')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (value) => provider.updateUserRole(user['id'], value!),
                      )),
                      DataCell(Text(user['created_at']?.toString().substring(0, 10) ?? '')),
                      DataCell(Row(
                        children: [
                          IconButton(icon: const Icon(Icons.block, color: Colors.red), onPressed: () {}),
                        ],
                      )),
                    ])).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
