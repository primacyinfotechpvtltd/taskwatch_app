import 'package:pi_task_watch/exports.dart';

class ProjectController extends GetxController {
  final RxList<ProjectModel> _projectList = <ProjectModel>[].obs;
  List<ProjectModel> get projectList => _projectList;
  RxBool isLoading = false.obs;

  Future<List<ProjectModel>> getAllProject() async {
    try {
      isLoading.value = true;

      final apiResponse = await ApiManager.getRequest(endPoint: "projects");

      final projectList = (apiResponse.body['data'] as List)
          .map((e) => ProjectModel.fromJson(e))
          .toList();
      _projectList.value = projectList;
      return projectList;
    } catch (e) {
      _projectList.value = [];
      return [];
    } finally {
      isLoading.value = false;
    }
  }
}
