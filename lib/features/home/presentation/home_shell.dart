import 'package:flutter/material.dart';

import '../../../models/profile.dart';
import '../../admin/presentation/admin_page.dart';
import '../../community/presentation/community_page.dart';
import '../../home/presentation/home_page.dart';
import '../../library/presentation/library_page.dart';
import '../../profile/presentation/profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.profile});
  final Profile profile;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final homeKey = GlobalKey<HomePageState>();
  final libraryKey = GlobalKey<LibraryPageState>();
  final communityKey = GlobalKey<CommunityPageState>();
  final adminKey = GlobalKey<AdminPageState>();

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(key: homeKey, profile: widget.profile),
      LibraryPage(key: libraryKey, profile: widget.profile),
      CommunityPage(key: communityKey),
      if (widget.profile.isAdmin) AdminPage(key: adminKey),
      ProfilePage(profile: widget.profile),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() {
          index = value;
          if (value == 0) {
            homeKey.currentState?.loadBooks();
          }
          if (value == 1) {
            libraryKey.currentState?.reload();
          }
          if (value == 2) {
            communityKey.currentState?.reload();
          }
          if (widget.profile.isAdmin && value == 3) {
            adminKey.currentState?.reload();
          }
        }),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.search_rounded),
            label: 'Discover',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bookmark_outline_rounded),
            label: 'My library',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            label: 'Readers',
          ),
          if (widget.profile.isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: 'Admin',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
