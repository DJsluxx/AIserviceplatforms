import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/package_model.dart';
import '../../data/repositories/package_repository.dart';

final homeInboxProvider = FutureProvider<InboxModel>((ref) async {
  final repo = ref.watch(packageRepositoryProvider);
  return repo.inbox();
});
