// lib/screens/notifiche_screen.dart
import 'package:flutter/material.dart';
import '../widgets/bottom_navbar.dart';

class NotificheScreen extends StatefulWidget {
  const NotificheScreen({super.key});

  @override
  State<NotificheScreen> createState() => _NotificheScreenState();
}

class _NotificheScreenState extends State<NotificheScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Benvenuta in Occhio al Borgo!',
      'body': 'Inizia a esplorare i borghi e guadagna i tuoi primi badge!',
      'time': '1h fa',
      'read': false,
    },
    {
      'title': 'Nuovo evento disponibile',
      'body': 'Scopri gli eventi in arrivo nei borghi vicini.',
      'time': '2h fa',
      'read': true,
    },
    {
      'title': 'Hai sbloccato un nuovo badge!',
      'body': 'Congratulazioni, hai visitato 5 borghi!',
      'time': 'Ieri',
      'read': true,
    },
  ];

  // 🔹 Handler per navbar
  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/explore');
        break;
      case 2:
        Navigator.pushNamed(context, '/scatta');
        break;
      case 3:
        // siamo già qui
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profilo');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFe8e9ea),
      appBar: AppBar(
        title: const Text('Notifiche', style: TextStyle(fontFamily: 'Cinzel')),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 3,
        onTap: _onNavTap,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: _notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final n = _notifications[index];
            final isRead = n['read'] as bool;
            return Dismissible(
              key: ValueKey(n['title']),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) {
                setState(() => _notifications.removeAt(index));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isRead
                        ? Colors.transparent
                        : const Color(0xFF91be7e),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: isRead
                          ? Colors.grey.shade600
                          : const Color(0xFF3a602a),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n['title'],
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            n['body'],
                            style: const TextStyle(
                              fontFamily: 'Cormorant',
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      n['time'],
                      style: const TextStyle(
                        fontFamily: 'Cormorant',
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
