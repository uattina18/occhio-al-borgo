import 'package:flutter/material.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Color? backgroundColor; // 👈 opzionale per override manuale

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        backgroundColor ??
        (isDark ? const Color(0xFF3a602a) : const Color(0xFF91be7e));
    final Color iconColor = isDark
        ? Colors.white
        : Colors.black87; // 👈 contrasto automatico

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home, 'Home', 0, iconColor),
          _buildNavItem(context, Icons.explore, 'Esplora', 1, iconColor),
          _buildCentralButton(context),
          _buildNavItem(
            context,
            Icons.notifications,
            'Notifiche',
            3,
            iconColor,
          ),
          _buildNavItem(context, Icons.person, 'Profilo', 4, iconColor),
        ],
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
    final bool isActive = index == currentIndex;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color activeColor = isDark
        ? Colors.white
        : Colors.black; // 👈 leggibile in entrambi i temi

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onTap(index),
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

  Widget _buildCentralButton(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color buttonColor = isDark ? Colors.white : Colors.black;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => onTap(2),
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
