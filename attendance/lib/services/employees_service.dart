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
        email: 'alice@example.com',
        role: 'admin', // EMP001 is Admin
        isPresentToday: false,
        time: '—',
      ),
      Employee(
        id: 'EMP002',
        name: 'Eva Martinez',
        department: 'Design',
        email: 'eva@example.com',
        role: 'employee',
        isPresentToday: false,
        time: '—',
      ),
      Employee(
        id: 'EMP003',
        name: 'James Wilson',
        department: 'Marketing',
        email: 'james@example.com',
        role: 'employee',
        isPresentToday: false,
        time: '—',
      ),
    ];
  }
}
