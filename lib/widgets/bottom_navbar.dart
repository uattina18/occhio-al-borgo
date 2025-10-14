import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Color(0xFF91be7e),
        border: Border(top: BorderSide(color: Colors.black12, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildNavItem(Icons.home, 'Home', 0),
          _buildNavItem(Icons.explore, 'Esplora', 1),
          _buildCentralButton(context),
          _buildNavItem(Icons.notifications, 'Notifiche', 3),
          _buildNavItem(Icons.person, 'Profilo', 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isActive = index == currentIndex;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onTap(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? Colors.black : Colors.black87,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Cinzel',
                color: isActive ? Colors.black : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCentralButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => onTap(2),
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.3,
              ), // ✅ nuovo metodo non deprecato
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.camera_alt, color: Colors.white, size: 26),
      ),
    );
  }
}
