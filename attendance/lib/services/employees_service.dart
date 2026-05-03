// ── 2B. EmployeeService
//    Responsible for: fetching employee list
import 'package:attendance/models/employees_model.dart';

class EmployeeService {
  Future<List<Employee>> getAllEmployees() async {
    // final snapshot = await FirebaseFirestore.instance
    //     .collection('employees')
    //     .get();
    // return snapshot.docs
    //     .map((doc) => Employee.fromMap({...doc.data(), 'id': doc.id}))
    //     .toList();

    await Future.delayed(const Duration(seconds: 1));
    return [
      Employee(
        id: 'EMP001',
        name: 'Alice Johnson',
        department: 'Engineering',
        email: '',
        role: '',
      ),
      Employee(
        id: 'EMP002',
        name: 'Eva Martinez',
        department: 'Design',
        email: '',
        role: '',
      ),
      Employee(
        id: 'EMP003',
        name: 'James Wilson',
        department: 'Marketing',
        email: '',
        role: '',
      ),
    ];
  }
}
