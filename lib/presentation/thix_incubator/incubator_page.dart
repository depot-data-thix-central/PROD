import 'package:flutter/material.dart';

class IncubatorPage extends StatelessWidget {
  const IncubatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0A5CFF);
    const textDark = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text("𝒯", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text("THIX ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                    Text("INCUBATEUR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor)),
                  ],
                ),
                const Text("Innover aujourd'hui, impacter demain.", style: TextStyle(fontSize: 8, color: Color(0xFF64748B))),
              ],
            )
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
            onPressed: () {},
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 22),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Text("3", style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12.0, left: 4),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Bannière Bienvenue épurée pour mobile
              _buildMobileWelcomeBanner(primaryColor),
              const SizedBox(height: 16),
              
              // 2. Grille d'actions rapides (Défilement horizontal pour éviter d'étouffer l'écran)
              _buildSectionHeader("Actions rapides"),
              const SizedBox(height: 8),
              _buildMobileQuickActions(primaryColor),
              const SizedBox(height: 20),
              
              // 3. Statut des projets (Format cartes verticales clean)
              _buildSectionHeader("Statut de mes projets"),
              const SizedBox(height: 8),
              _buildProjectCard(
                logo: Icons.eco_outlined,
                logoColor: Colors.green,
                title: "AgriTech Solutions",
                progress: 0.75,
                progressText: "75%",
                tag: "En incubation",
                tagColor: Colors.green,
                phase: "Prototype",
                date: "30 Juin 2026",
              ),
              const SizedBox(height: 10),
              _buildProjectCard(
                logo: Icons.school_outlined,
                logoColor: Colors.purple,
                title: "EduConnect",
                progress: 0.40,
                progressText: "40%",
                tag: "En évaluation",
                tagColor: Colors.orange,
                phase: "Idéation",
                date: "15 Août 2026",
              ),
              const SizedBox(height: 20),
              
              // 4. Ressources disponibles
              _buildSectionHeader("Ressources pour vous"),
              const SizedBox(height: 8),
              _buildMobileResources(),
              const SizedBox(height: 20),
              
              // 5. Mentors disponibles (Format Liste Horizontale tactile)
              _buildSectionHeader("Mentors disponibles"),
              const SizedBox(height: 8),
              _buildMobileMentors(),
              const SizedBox(height: 20),
              
              // 6. Événements à venir
              _buildMobileEvents(primaryColor),
              const SizedBox(height: 16),
              
              // 7. Opportunités
              _buildMobileOpportunities(),
              const SizedBox(height: 16),
              
              // 8. Communauté THIX
              _buildMobileCommunity(primaryColor),
              const SizedBox(height: 16),
              
              // 9. Bannière d'appel à l'action finale (Bas de page)
              _buildBottomActionBanner(primaryColor),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavbar(primaryColor),
    );
  }

  // --- COMPOSANTS ADAPTÉS AU TÉLÉPHONE ---

  Widget _buildMobileWelcomeBanner(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Bienvenue dans THIX Incubateur 👋",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            "L'écosystème qui propulse vos idées en entreprises à fort impact.",
            style: TextStyle(color: Color(0xFF475569), fontSize: 11, height: 1.3),
          ),
          const SizedBox(height: 12),
          
          // Statistiques miniaturisées en ligne défilante
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildMiniStatCard("Projets incubés", "128", Icons.business_center, Colors.blue.shade50, primaryColor),
                const SizedBox(width: 8),
                _buildMiniStatCard("Startups créées", "56", Icons.trending_up, Colors.green.shade50, Colors.green),
                const SizedBox(width: 8),
                _buildMiniStatCard("Emplois générés", "342", Icons.people, Colors.orange.shade50, Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text("Soumettre mon projet", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value, IconData icon, Color bgIcon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 12),
          const SizedBox(width: 6),
          Text("$label: ", style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildMobileQuickActions(Color primaryColor) {
    final actions = [
      {'icon': Icons.note_add_outlined, 'title': 'Soumettre'},
      {'icon': Icons.folder_open_outlined, 'title': 'Projets'},
      {'icon': Icons.account_balance_wallet_outlined, 'title': 'Finance'},
      {'icon': Icons.co_present_outlined, 'title': 'Mentorat'},
      {'icon': Icons.school_outlined, 'title': 'Formations'},
    ];

    return SizedBox(
      height: 68,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final act = actions[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 65,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                  ),
                  child: Icon(act['icon'] as IconData, color: primaryColor, size: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  act['title'] as String, 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProjectCard({
    required IconData logo,
    required Color logoColor,
    required String title,
    required double progress,
    required String progressText,
    required String tag,
    required Color tagColor,
    required String phase,
    required String date,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: logoColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(logo, color: logoColor, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            height: 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(value: progress, backgroundColor: const Color(0xFFE2E8F0), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A5CFF))),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(progressText, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  )
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: tagColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(tag, style: TextStyle(color: tagColor, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Phase : $phase", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              Text("Échéance : $date", style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMobileResources() {
    final resources = [
      {'icon': Icons.backpack_outlined, 'title': 'Guides'},
      {'icon': Icons.article_outlined, 'title': 'Templates'},
      {'icon': Icons.analytics_outlined, 'title': 'Études'},
    ];

    return Row(
      children: resources.map((res) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Icon(res['icon'] as IconData, color: const Color(0xFF0A5CFF), size: 16),
                const SizedBox(height: 4),
                Text(res['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9), maxLines: 1),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileMentors() {
    final mentors = [
      {'name': 'Jean N\'guessan', 'role': 'Entrepreneur'},
      {'name': 'Fatou Diallo', 'role': 'Marketing'},
      {'name': 'Koffi Mensah', 'role': 'Tech Expert'},
    ];

    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: mentors.length,
        itemBuilder: (context, index) {
          final m = mentors[index];
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(radius: 14, backgroundColor: Colors.blueGrey, child: Icon(Icons.person, color: Colors.white, size: 14)),
                const SizedBox(height: 4),
                Text(m['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(m['role']!, style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)), maxLines: 1),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileEvents(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSideHeader("Événements à venir"),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                    child: const Text("24\nMAI", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0A5CFF), height: 1.1)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Atelier Pitch Deck", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      Text("09:00 • En ligne", style: TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  )
                ],
              ),
              TextButton(onPressed: () {}, child: Text("S'inscrire", style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold)))
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMobileOpportunities() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSideHeader("Opportunités"),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.eco_outlined, color: Colors.purple, size: 16),
              SizedBox(width: 6),
              Expanded(child: Text("Financement Seed (10M FCFA)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMobileCommunity(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("Communauté THIX", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              Text("Échangez avec les incubés.", style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
            ],
          ),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0),
              child: const Text("Rejoindre", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBottomActionBanner(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [Color(0xFF0A5CFF), Color(0xFF003BB3)]),
      ),
      child: Column(
        children: [
          const Text("Vous avez une idée ?", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text("Transformez-la en une grande entreprise.", style: TextStyle(color: Colors.white70, fontSize: 10), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              child: Text("Démarrer", style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const Text("Voir tout", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildSideHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)));
  }

  Widget _buildBottomNavbar(Color primaryColor) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 9,
      unselectedFontSize: 9,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home, size: 18), label: 'Accueil'),
        const BottomNavigationBarItem(icon: Icon(Icons.folder_open, size: 18), label: 'Projets'),
        BottomNavigationBarItem(icon: CircleAvatar(radius: 14, backgroundColor: primaryColor, child: const Icon(Icons.add, color: Colors.white, size: 16)), label: ''),
        const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline, size: 18), label: 'Messages'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 18), label: 'Profil'),
      ],
    );
  }
}
