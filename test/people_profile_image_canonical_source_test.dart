import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('People profile images use canonical Image Relation UI', () {
    final people =
        File('lib/views/people_management_page.dart').readAsStringSync();
    final widget =
        File('lib/widgets/person_profile_image.dart').readAsStringSync();
    final service = File(
      'lib/services/person_profile_image_relation_service.dart',
    ).readAsStringSync();

    expect(people, contains('createPersonProfileImageRelationService(repository)'));
    expect(people, contains('PersonProfileImageMedia('));
    expect(people, contains('PersonProfileImageEditor('));
    expect(people, isNot(contains('repository.watchPhotos()')));
    expect(people, isNot(contains('showPhotoDatabasePicker(')));
    expect(people, isNot(contains('PhotoRecord')));
    expect(people, isNot(contains('File(photo.path)')));
    expect(people, isNot(contains('profilePhotoId')));

    expect(widget, contains('showObjectRelationPickerDialog('));
    expect(widget, contains('selection: state.relation'));
    expect(widget, contains('.setProfileImage('));
    expect(widget, contains('.clearProfileImage('));
    expect(widget, contains('ImageVisualResolver('));

    expect(
      service,
      contains('Future<List<ObjectIdentitySearchResult>> searchImages({'),
    );
    expect(service, contains("profileImagePropertyName = 'Profile Image'"));
    expect(service, contains('selectionForMutation('));
  });
}
