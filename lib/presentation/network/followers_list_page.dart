import 'package:flutter/material.dart'; // ✅ i minuscule !
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Imports pour la certification
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';

class FollowersListPage extends StatefulWidget {
  final String userId;
  const FollowersListPage({super.key, required this.userId});
  
  @override 
  State<FollowersListPage> createState() => _FollowersListPageState();
}

class _FollowersListPageState extends State<FollowersListPage> {
  List<Map<String, dynamic>> all = [];
  bool loading = true;
  String _searchQuery = '';

  @override 
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; });
    try {
      // ÉTAPE 1 : On récupère juste les IDs des gens qui suivent cet utilisateur
      final followsRes = await Supabase.instance.client
          .from('follows')
          .select('follower_id')
          .eq('following_id', widget.userId);
          
      final List followsList = followsRes as List;
      
      if (followsList.isEmpty) {
        if (mounted) setState(() { all = []; loading = false; });
        return;
      }

      // On extrait la liste des IDs
      final List<String> followerIds = followsList.map((e) => e['follower_id'].toString()).toList();

      // ÉTAPE 2 : On récupère les profils correspondants (avec les colonnes de certification ✅)
      final profilesRes = await Supabase.instance.client
          .from('profiles')
          .select('id, display_name, photo_url, avatar_url, certification_tier, certification_status, is_verified')
          .inFilter('id', followerIds);

      // On reformate pour l'interface
      final formattedList = (profilesRes as List).map((profile) {
        return {
          'follower_id': profile['id'],
          'profiles': profile,
        };
      }).toList();

      if (mounted) {
        setState(() {
          all = formattedList;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('🚨 ERREUR Followers: $e');
      if (mounted) setState(() { loading = false; });
    }
  }

  @override 
  Widget build(BuildContext context) {
    final filteredList = all.where((item) {
      final profile = item['profiles'] as Map<String, dynamic>?;
      final name = profile != null ? (profile['display_name'] ?? 'User') as String : 'User';
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          'Abonnés (${all.length})',
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Rechercher un abonné...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: load,
                    child: filteredList.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty 
                                  ? 'Aucun abonné.' 
                                  : 'Aucun résultat trouvé.',
                              style: const TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: filteredList.length,
                            separatorBuilder: (context, i) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            itemBuilder: (context, i) {
                              final item = filteredList[i];
                              final profile = item['profiles'] as Map<String, dynamic>?;
                              final fid = item['follower_id'] as String;
                              final name = profile != null ? (profile['display_name'] ?? 'User') as String : 'User';
                              final photo = profile != null ? (profile['photo_url'] ?? profile['avatar_url']) as String? : null;

                              // Extraction de la certification
                              CertificationTier? tier;
                              CertificationStatus? status;
                              bool isCertified = false;
                              bool isLegacyVerified = false;

                              if (profile != null) {
                                tier = CertificationTierX.parse(profile['certification_tier']);
                                status = CertificationStatusX.parse(profile['certification_status']);
                                isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
                                isLegacyVerified = profile['is_verified'] == true;
                              }

                              Widget avatarWidget;
                              if (photo != null && photo.isNotEmpty) {
                                avatarWidget = CircleAvatar(backgroundImage: NetworkImage(photo));
                              } else {
                                avatarWidget = const CircleAvatar(
                                  backgroundColor: Color(0xFFF1F5F9),
                                  child: Icon(Icons.person, color: Colors.grey),
                                );
                              }

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: avatarWidget,
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name, 
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCertified)
                                      CertificationNameBadge(
                                        tier: tier,
                                        status: status,
                                        showLabel: false,
                                        iconSize: 15,
                                        padding: const EdgeInsets.only(left: 4),
                                      )
                                    else if (isLegacyVerified)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.verified_rounded, color: Color(0xFFE3B23C), size: 15),
                                      ),
                                  ],
                                ),
                                onTap: () => context.push('/network/profile/$fid'),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
