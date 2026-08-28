import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diet_app2/model/statistics.dart';

class StatisticsRepository {
  static final _db = FirebaseFirestore.instance;
  static addMealData(Statistics statistics_data) async{
    final data =statistics_data.toMap();
    final collection_name = data["names"].length.toString()+ "_component_stat";
    await _db.collection(collection_name).add(data);
  }
}
