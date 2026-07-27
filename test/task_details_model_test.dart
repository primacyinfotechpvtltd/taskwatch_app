import 'package:flutter_test/flutter_test.dart';
import 'package:pi_task_watch/models/task_details_model.dart';

void main() {
  test('TaskDetailsModel.fromJson should parse sample task response correctly',
      () {
    final model = TaskDetailsModel.fromJson({
      'id': 6048,
      'name': 'Team meeting & project management',
      'project_id': [170, 'primacy inhouse'],
      'stage_id': [804, 'Meeting'],
      'date_start': '2026-01-22 10:30:00',
      'date_deadline': '2026-01-22 11:00:00',
      'allocated_time_in_hours': '0:00',
      'used_time': '801:26',
      'task_url':
          'http://192.168.1.17:8098/web#id=6048&model=project.task&view_type=form',
    });

    // Verify fields
    expect(model.id, 6048);
    expect(model.name, 'Team meeting & project management');
    expect(model.projectId, 170);
    expect(model.projectName, 'primacy inhouse');
    expect(model.stageId, 804);
    expect(model.stageName, 'Meeting');

    // Verify aliased fields
    expect(model.dateStart, DateTime.parse('2026-01-22 10:30:00'));
    expect(model.dateDeadline, DateTime.parse('2026-01-22 11:00:00'));

    // Verify duration parsing
    // "0:00" -> 0.0
    expect(model.allocatedHours, 0.0);

    // Verify new fields
    expect(model.usedTime, '801:26');
    expect(model.taskUrl,
        'http://192.168.1.17:8098/web#id=6048&model=project.task&view_type=form');
  });

  test('TaskDetailsModel.fromJson should handle duration strings like 1:30',
      () {
    final json = {
      'id': 1,
      'name': 'Test Task',
      'allocated_time_in_hours': '1:30',
      'stage_id': 10,
    };

    final model = TaskDetailsModel.fromJson(json);
    expect(model.allocatedHours, 1.5);
  });
}
