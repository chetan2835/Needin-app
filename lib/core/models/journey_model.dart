// ══════════════════════════════════════════════════════════════
//  JOURNEY MODEL — Complete data model for Traveler Journeys
//  Maps 1:1 to Supabase 'journeys' table
// ══════════════════════════════════════════════════════════════

class Journey {
  final String id;
  final String driverId;
  final String driverName;
  final String origin;
  final String destination;
  final String capacity;
  final String driverRating;
  final String driverAvatarUrl;
  final double? distanceKm;
  final String? travelMode;
  final String? durationText;
  final String status;

  // Extended fields for full journey flow
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final String? routePolyline;
  final String? departureTime;
  final String? dimensions;
  final String? pickupFlexibility;
  final String? dropoffFlexibility;
  final String? acceptableParcelSizes;
  final String? additionalNotes;
  final double? priceMedium;
  final double? priceSmall;
  final double? priceLarge;
  final String? createdAt;

  Journey({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.origin,
    required this.destination,
    required this.capacity,
    required this.driverRating,
    required this.driverAvatarUrl,
    this.distanceKm,
    this.travelMode,
    this.durationText,
    this.status = 'active',
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    this.routePolyline,
    this.departureTime,
    this.dimensions,
    this.pickupFlexibility,
    this.dropoffFlexibility,
    this.acceptableParcelSizes,
    this.additionalNotes,
    this.priceMedium,
    this.priceSmall,
    this.priceLarge,
    this.createdAt,
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      id: json['id']?.toString() ?? '',
      driverId:
          json['driver_id']?.toString() ?? json['user_id']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? 'Traveler',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      capacity:
          json['capacity_kg']?.toString() ?? json['capacity']?.toString() ?? '',
      driverRating: json['driver_rating']?.toString() ?? '5.0',
      driverAvatarUrl:
          json['driver_avatar_url']?.toString() ??
          json['profile_image_url']?.toString() ??
          '',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      travelMode: json['travel_mode']?.toString(),
      durationText:
          json['duration_text']?.toString() ??
          json['estimated_duration']?.toString(),
      status: json['status']?.toString() ?? 'active',
      originLat: (json['origin_lat'] as num?)?.toDouble(),
      originLng: (json['origin_lng'] as num?)?.toDouble(),
      destLat:
          (json['dest_lat'] as num?)?.toDouble() ??
          (json['destination_lat'] as num?)?.toDouble(),
      destLng:
          (json['dest_lng'] as num?)?.toDouble() ??
          (json['destination_lng'] as num?)?.toDouble(),
      routePolyline: json['route_polyline']?.toString(),
      departureTime: json['departure_time']?.toString(),
      dimensions: json['dimensions']?.toString(),
      pickupFlexibility: json['pickup_flexibility']?.toString(),
      dropoffFlexibility: json['dropoff_flexibility']?.toString(),
      acceptableParcelSizes: json['acceptable_parcel_sizes']?.toString(),
      additionalNotes: json['additional_notes']?.toString(),
      priceMedium: (json['price_medium'] as num?)?.toDouble(),
      priceSmall: (json['price_small'] as num?)?.toDouble(),
      priceLarge: (json['price_large'] as num?)?.toDouble(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'driver_id': driverId,
    'origin': origin,
    'destination': destination,
    'status': status,
    if (distanceKm != null) 'distance_km': distanceKm,
    if (travelMode != null) 'travel_mode': travelMode,
    if (durationText != null) 'duration_text': durationText,
    if (originLat != null) 'origin_lat': originLat,
    if (originLng != null) 'origin_lng': originLng,
    if (destLat != null) 'dest_lat': destLat,
    if (destLng != null) 'dest_lng': destLng,
    if (routePolyline != null) 'route_polyline': routePolyline,
    if (departureTime != null) 'departure_time': departureTime,
    if (dimensions != null) 'dimensions': dimensions,
    if (pickupFlexibility != null) 'pickup_flexibility': pickupFlexibility,
    if (dropoffFlexibility != null) 'dropoff_flexibility': dropoffFlexibility,
    if (acceptableParcelSizes != null)
      'acceptable_parcel_sizes': acceptableParcelSizes,
    if (additionalNotes != null) 'additional_notes': additionalNotes,
    if (priceMedium != null) 'price_medium': priceMedium,
    if (priceSmall != null) 'price_small': priceSmall,
    if (priceLarge != null) 'price_large': priceLarge,
  };

  /// Friendly formatted departure time
  String get formattedDepartureTime {
    if (departureTime == null) return 'Not set';
    try {
      final dt = DateTime.parse(departureTime!);
      final months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      final ampm = dt.hour >= 12 ? "PM" : "AM";
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      return "${months[dt.month - 1]} ${dt.day}, $hour12:$minute $ampm";
    } catch (_) {
      return departureTime!;
    }
  }

  /// Earnings range text
  String get earningsText {
    if (priceSmall != null && priceLarge != null) {
      return "₹${priceSmall!.toStringAsFixed(0)}–₹${priceLarge!.toStringAsFixed(0)}";
    }
    if (priceMedium != null) return "₹${priceMedium!.toStringAsFixed(0)}";
    return "₹--";
  }

  /// Human-friendly travel mode icon
  String get travelModeLabel => travelMode ?? 'Road';

  /// Status display
  bool get isLive => status == 'active' || status == 'live';
  bool get isCompleted => status == 'completed';
  bool get isDraft => status == 'draft';
}
