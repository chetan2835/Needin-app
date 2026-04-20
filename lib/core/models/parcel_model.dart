class Parcel {
  final String id;
  final String title;
  final String subtitle;
  final String statusBadgeText;
  final String statusType; // e.g. 'active', 'draft'

  Parcel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.statusBadgeText,
    required this.statusType,
  });

  factory Parcel.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'pending';
    final origin = json['origin']?.toString() ?? '';
    final destination = json['destination']?.toString() ?? '';
    return Parcel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Parcel',
      subtitle: origin.isNotEmpty && destination.isNotEmpty
          ? '$origin → $destination'
          : json['subtitle']?.toString() ?? '',
      statusBadgeText: status.toUpperCase(),
      statusType: status,
    );
  }
}
