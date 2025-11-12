import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';
import 'package:occhio_al_borgo/l10n/app_localizations.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Color? backgroundColor;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        widget.backgroundColor ??
        (isDark ? const Color(0xFF3a602a) : const Color(0xFF91be7e));
    final Color iconBaseColor = isDark
        ? Colors.white
        : Colors.black87; // contrasto automatico

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, snapshot) {
          int pendingCount = 0;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data()!;
            final pending = List<String>.from(data['pendingRequests'] ?? []);
            pendingCount = pending.length;
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, Icons.home, loc.homeTab, 0, iconBaseColor),
              _buildNavItem(
                context,
                Icons.explore,
                loc.exploreTab,
                1,
                iconBaseColor,
              ),
              _buildCentralButton(context),
              _buildNotificationItem(
                context,
                pendingCount,
                loc.notificationsTab,
                iconBaseColor,
              ),
              _buildNavItem(
                context,
                Icons.person,
                loc.profileTab,
                4,
                iconBaseColor,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    Color baseColor,
  ) {
    final bool isActive = index == widget.currentIndex;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color activeColor = isDark ? Colors.white : Colors.black;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => widget.onTap(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: isActive ? activeColor : baseColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Cinzel',
                color: isActive ? activeColor : baseColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    int pendingCount,
    String label,
    Color baseColor,
  ) {
    final bool isActive = widget.currentIndex == 3;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color activeColor = isDark ? Colors.white : Colors.black;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => widget.onTap(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications,
                  size: 22,
                  color: isActive ? activeColor : baseColor,
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          pendingCount > 9 ? '9+' : '$pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Cinzel',
                color: isActive ? activeColor : baseColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCentralButton(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color buttonColor = isDark ? Colors.white : Colors.black;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => widget.onTap(2),
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.camera_alt,
          color: isDark ? Colors.black : Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
