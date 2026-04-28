// ── 2C. OfficeService
//    Responsible for: get and update office location config
import '../models/office_location_model.dart';

class OfficeService {
  Future<OfficeLocation?> getOfficeLocation() async {
    // final doc = await FirebaseFirestore.instance
    //     .collection('config')
    //     .doc('officeLocation')
    //     .get();
    // if (!doc.exists) return null;
    // return OfficeLocation.fromMap(doc.data()!);

    await Future.delayed(const Duration(milliseconds: 500));
    return OfficeLocation(
      name: 'Osquare',
      latitude: 24.0000,
      longitude: 67.0000,
      radiusInMeters: 100,
    );
  }

  Future<void> updateOfficeLocation(OfficeLocation location) async {
    // await FirebaseFirestore.instance
    //     .collection('config')
    //     .doc('officeLocation')
    //     .set(location.toMap());

    await Future.delayed(const Duration(milliseconds: 500));
  }
}
