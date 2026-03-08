import '../entities/department.dart';
import '../repositories/navigation_repository.dart';

class GetDepartments {
  final NavigationRepository repository;

  GetDepartments(this.repository);

  Future<List<Department>> call() {
    return repository.getAllDepartments();
  }
}
