import 'package:flutter/material.dart';
import 'package:login_fish_app/backend-login/login.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/homepage/GalleryScreen/Gallery.dart';
import 'package:login_fish_app/homepage/FilterScreen/filter.dart';
import 'package:login_fish_app/services/filter_bus.dart';
//import 'package:flutterfishapp/UserScreen/user.dart';
import 'package:login_fish_app/homepage/SettingsScreen/settings.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.65,
      backgroundColor: AppTheme.surfaceColor.withOpacity(0.98),
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Space to align below hamburger icon (approx. half of AppBar height)
          SizedBox(height: kToolbarHeight * 0.7),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildListTile(
                  icon: Icons.photo_library,
                  text: 'Gallery',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Gallery()),
                    );
                  },
                ),
                Divider(color: AppTheme.textColor.withOpacity(0.3)),
                _buildListTile(
                  icon: Icons.filter_alt,
                  text: 'Filters',
                  onTap: () async {
                    // Close the drawer first so Filter opens on top of the full MapScreen
                    Navigator.pop(context);
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Filter()),
                    );
                    try {
                      if (res is Map && res['clearFilter'] == true) {
                        FilterBus.instance.publish(null);
                      }
                    } catch (_) {}
                  },
                ),
                Divider(color: AppTheme.textColor.withOpacity(0.3)),
                _buildListTile(
                  icon: Icons.settings,
                  text: 'Settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Settings()),
                    );
                  },
                ),
                Divider(color: AppTheme.textColor.withOpacity(0.3)),
                _buildListTile(
                  icon: Icons.logout,
                  text: 'Logout',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Login()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textColor, size: 22),
      title: Text(
        text,
        style: TextStyle(
          color: AppTheme.textColor,
          fontFamily: AppTheme.fontFamily,
          fontSize: 16,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 24,
      dense: true,
      onTap: onTap,
    );
  }
}
