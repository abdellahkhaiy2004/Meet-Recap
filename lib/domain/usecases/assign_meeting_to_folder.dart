import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/folder_repository.dart';
import '../../data/repositories/meeting_repository.dart';

/// Use-case: move a meeting from its current folder to [targetFolderId].
///
/// Validates that the target folder exists before calling the repository.
/// Exposed as a provider so pages can read it without coupling to
/// MeetingRepository directly.
class AssignMeetingToFolder {
  const AssignMeetingToFolder({
    required MeetingRepository meetingRepo,
    required FolderRepository folderRepo,
  })  : _meetingRepo = meetingRepo,
        _folderRepo = folderRepo;

  final MeetingRepository _meetingRepo;
  final FolderRepository _folderRepo;

  Future<bool> call(int meetingId, int targetFolderId) async {
    final folder = await _folderRepo.getById(targetFolderId);
    if (folder == null) return false;
    await _meetingRepo.moveToFolder(meetingId, targetFolderId);
    return true;
  }
}

final assignMeetingToFolderProvider = Provider<AssignMeetingToFolder>((ref) {
  return AssignMeetingToFolder(
    meetingRepo: ref.watch(meetingRepositoryProvider),
    folderRepo: ref.watch(folderRepositoryProvider),
  );
});
