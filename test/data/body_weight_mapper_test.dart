import 'package:diet_app2/data/mappers/body_weight_mapper.dart';
import 'package:diet_app2/domain/body/body_weight.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weight round-trip keeps dates and kg', () {
    final date = DateTime(2026, 11, 6);
    final entry = BodyWeightEntry(
      dateKey: '2026-11-06',
      date: date,
      kg: 78.5,
      createdAt: date,
      updatedAt: date,
    );
    final json = BodyWeightMapper.toJson(entry);
    expect(json['date'], isA<Timestamp>());
    expect(BodyWeightMapper.fromJson(json, dateKey: entry.dateKey), entry);
  });
}
