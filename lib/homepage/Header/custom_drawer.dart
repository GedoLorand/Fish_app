import 'package:flutter/material.dart';
import 'package:login_fish_app/backend-login/login.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/homepage/GalleryScreen/Gallery.dart';
import 'package:login_fish_app/homepage/FilterScreen/filter.dart';
// import 'package:login_fish_app/homepage/AIScreen/ai_assistant.dart';
import 'package:login_fish_app/services/filter_bus.dart';
//import 'package:flutterfishapp/UserScreen/user.dart';
import 'package:login_fish_app/homepage/SettingsScreen/settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Admin/reports_admin.dart';
import 'package:login_fish_app/homepage/LegalScreen/legal_links.dart';
import 'package:login_fish_app/homepage/LegalScreen/legal_webview.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen(
      (u) => setState(() => _user = u),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.65,
      backgroundColor: AppTheme.surfaceColor.withValues(alpha: 0.98),
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
                  text: 'gallery',
                  onTap: () {
                    // Close drawer first so navigation happens from the underlying
                    // screen (usually MapScreen). Then await result from Gallery
                    // and publish an owner-only filter so MapScreen can react.
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Gallery()),
                    ).then((res) {
                      try {
                        if (res is Map && res['showOnlyMine'] == true) {
                          FilterBus.instance.publish({'ownerOnly': true});
                        }
                      } catch (_) {}
                    });
                  },
                ),
                Divider(color: AppTheme.textColor.withValues(alpha: 0.3)),
                _buildListTile(
                  icon: Icons.filter_alt,
                  text: 'filters',
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
                Divider(color: AppTheme.textColor.withValues(alpha: 0.3)),
                /*
                _buildListTile(
                  icon: Icons.smart_toy,
                  text: 'ai_assistant',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AIAssistantScreen(),
                      ),
                    );
                  },
                ),
                */
                Divider(color: AppTheme.textColor.withValues(alpha: 0.3)),
                _buildListTile(
                  icon: Icons.settings,
                  text: 'settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Settings()),
                    );
                  },
                ),
                Divider(color: AppTheme.textColor.withValues(alpha: 0.3)),
                _buildListTile(
                  icon: Icons.privacy_tip,
                  text: 'privacy_policy',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LegalWebViewScreen(
                          title: 'privacy_policy'.tr,
                          url: LegalLinks.privacyPolicyUrl,
                        ),
                      ),
                    );
                  },
                ),
                Divider(color: AppTheme.textColor.withValues(alpha: 0.3)),
                _buildListTile(
                  icon: Icons.description,
                  text: 'terms_conditions',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LegalWebViewScreen(
                          title: 'terms_conditions'.tr,
                          url: LegalLinks.termsAndConditionsUrl,
                        ),
                      ),
                    );
                  },
                ),
                Divider(color: AppTheme.textColor.withValues(alpha: 0.3)),
                // Admin-only reports screen
                if (_user != null &&
                    (_user!.email == 'gedolorand@gmail.com' ||
                        _user!.isAnonymous == false && false))
                  _buildListTile(
                    icon: Icons.report,
                    text: 'reports',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportsAdminScreen(),
                        ),
                      );
                    },
                  ),
                Divider(color: AppTheme.textColor.withValues(alpha: 0.3)),
                _buildListTile(
                  icon: Icons.logout,
                  text: 'logout',
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
        text.tr,
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
