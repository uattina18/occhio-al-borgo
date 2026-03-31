import 'dart:math';

class EventItem {
  final String title;
  final String date;
  final double lat;
  final double lng;

  EventItem({
    required this.title,
    required this.date,
    required this.lat,
    required this.lng,
  });
}

double haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

List<EventItem> filterEventsByDistance({
  required List<EventItem> events,
  required double userLat,
  required double userLng,
  double maxKm = 25,
}) {
  return events.where((ev) {
    final dist = haversine(userLat, userLng, ev.lat, ev.lng);
    return dist <= maxKm;
  }).toList();
}
