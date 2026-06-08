import 'dart:math' as math;

class SettlementReservation {
  const SettlementReservation({
    required this.id,
    required this.creatorId,
    required this.departureLocation,
    required this.destinationLocation,
    required this.routeDistanceMeters,
  });

  final int id;
  final String creatorId;
  final String departureLocation;
  final String destinationLocation;
  final double routeDistanceMeters;

  factory SettlementReservation.fromJson(Map<String, dynamic> json) {
    return SettlementReservation(
      id: _asInt(json['id']),
      creatorId: json['creator_id']?.toString() ?? '',
      departureLocation: json['departure_location']?.toString() ?? '',
      destinationLocation: json['destination_location']?.toString() ?? '',
      routeDistanceMeters: _asDouble(json['route_distance_meters']),
    );
  }
}

class SettlementPassenger {
  SettlementPassenger({
    required this.id,
    required this.name,
    required this.email,
    required this.isCreator,
    required this.destinationLocation,
    required this.dropoffDistanceMeters,
  });

  final String id;
  final String name;
  final String email;
  final bool isCreator;
  final String destinationLocation;
  final double dropoffDistanceMeters;

  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    final trimmedEmail = email.trim();
    if (trimmedEmail.isNotEmpty) return trimmedEmail;
    return '사용자 $id';
  }

  factory SettlementPassenger.fromJson(Map<String, dynamic> json) {
    return SettlementPassenger(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isCreator: json['is_creator'] == true,
      destinationLocation: json['destination_location']?.toString() ?? '',
      dropoffDistanceMeters: _asDouble(json['dropoff_distance_meters']),
    );
  }
}

class SettlementData {
  const SettlementData({
    required this.currentUserId,
    required this.reservation,
    required this.passengers,
  });

  final String currentUserId;
  final SettlementReservation reservation;
  final List<SettlementPassenger> passengers;

  factory SettlementData.fromJson(Map<String, dynamic> json) {
    final passengerList = json['participants'] is List
        ? json['participants'] as List
        : const <dynamic>[];
    return SettlementData(
      currentUserId: json['current_user_id']?.toString() ?? '',
      reservation: SettlementReservation.fromJson(
        Map<String, dynamic>.from(json['reservation'] as Map),
      ),
      passengers: passengerList
          .whereType<Map>()
          .map(
            (entry) =>
                SettlementPassenger.fromJson(Map<String, dynamic>.from(entry)),
          )
          .where((passenger) => passenger.id.isNotEmpty)
          .toList(),
    );
  }
}

class SettlementSection {
  const SettlementSection({
    required this.name,
    required this.distanceMeters,
    required this.activePassengers,
    required this.sectionFare,
    required this.farePerPerson,
  });

  final String name;
  final double distanceMeters;
  final List<SettlementPassenger> activePassengers;
  final double sectionFare;
  final double farePerPerson;
}

class SettlementResult {
  const SettlementResult({
    required this.fareByPassenger,
    required this.sections,
    required this.finalSettler,
  });

  final Map<String, double> fareByPassenger;
  final List<SettlementSection> sections;
  final SettlementPassenger? finalSettler;
}

SettlementResult calculateSettlement({
  required List<SettlementPassenger> passengers,
  required double totalFare,
  required String creatorId,
}) {
  final sanitized = passengers
      .map(
        (passenger) => SettlementPassenger(
          id: passenger.id,
          name: passenger.name,
          email: passenger.email,
          isCreator: passenger.isCreator,
          destinationLocation: passenger.destinationLocation,
          dropoffDistanceMeters: math.max(0, passenger.dropoffDistanceMeters),
        ),
      )
      .toList();

  final fareByPassenger = {
    for (final passenger in sanitized) passenger.id: 0.0,
  };
  if (sanitized.isEmpty || totalFare <= 0) {
    return SettlementResult(
      fareByPassenger: fareByPassenger,
      sections: const [],
      finalSettler: null,
    );
  }

  final dropoffDistances =
      sanitized
          .map((passenger) => passenger.dropoffDistanceMeters)
          .where((distance) => distance > 0)
          .toSet()
          .toList()
        ..sort();

  if (dropoffDistances.isEmpty) {
    return SettlementResult(
      fareByPassenger: fareByPassenger,
      sections: const [],
      finalSettler: _resolveFinalSettler(sanitized, creatorId),
    );
  }

  final totalDistance = dropoffDistances.last;
  var previousDistance = 0.0;
  final sections = <SettlementSection>[];

  for (final dropoffDistance in dropoffDistances) {
    final sectionDistance = dropoffDistance - previousDistance;
    if (sectionDistance <= 0) continue;

    final activePassengers = sanitized
        .where(
          (passenger) =>
              passenger.dropoffDistanceMeters >= dropoffDistance - 0.000001,
        )
        .toList();
    if (activePassengers.isEmpty) {
      previousDistance = dropoffDistance;
      continue;
    }

    final sectionFare = totalFare * (sectionDistance / totalDistance);
    final farePerPerson = sectionFare / activePassengers.length;

    for (final passenger in activePassengers) {
      fareByPassenger[passenger.id] =
          (fareByPassenger[passenger.id] ?? 0) + farePerPerson;
    }

    sections.add(
      SettlementSection(
        name:
            '${_formatDistance(previousDistance)} -> ${_formatDistance(dropoffDistance)}',
        distanceMeters: sectionDistance,
        activePassengers: activePassengers,
        sectionFare: sectionFare,
        farePerPerson: farePerPerson,
      ),
    );

    previousDistance = dropoffDistance;
  }

  return SettlementResult(
    fareByPassenger: fareByPassenger,
    sections: sections,
    finalSettler: _resolveFinalSettler(sanitized, creatorId),
  );
}

SettlementPassenger? _resolveFinalSettler(
  List<SettlementPassenger> passengers,
  String creatorId,
) {
  if (passengers.isEmpty) return null;
  final maxDistance = passengers
      .map((passenger) => passenger.dropoffDistanceMeters)
      .reduce(math.max);
  final finalPassengers = passengers
      .where(
        (passenger) =>
            (passenger.dropoffDistanceMeters - maxDistance).abs() < 0.000001,
      )
      .toList();
  return finalPassengers.firstWhere(
    (passenger) => passenger.id == creatorId,
    orElse: () => finalPassengers.first,
  );
}

String formatCurrency(num value) {
  final rounded = value.round();
  final raw = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final remaining = raw.length - i;
    buffer.write(raw[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return '$buffer원';
}

String formatDistanceMeters(num meters) {
  return _formatDistance(meters.toDouble());
}

String _formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }
  return '${meters.round()}m';
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
