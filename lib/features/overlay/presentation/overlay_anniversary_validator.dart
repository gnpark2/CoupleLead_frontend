import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'overlay_anniversary_validator.dart';
import '../../anniversary/data/model/anniversary.dart';
import 'overlay_provider.dart';

Future<void> validateOverlayAnniversary({
  required WidgetRef ref,
  required List<Anniversary> anniversaries,
}) async {
  final settings = ref
      .read(
        overlaySettingsProvider,
      )
      .valueOrNull;

  if (settings == null) {
    return;
  }

  final selectedId =
      settings.anniversaryId;

  if (selectedId == null) {
    return;
  }

  final exists = anniversaries.any(
    (anniversary) =>
        anniversary.id == selectedId,
  );

  if (exists) {
    return;
  }

  await ref
      .read(
        overlaySettingsProvider.notifier,
      )
      .setAnniversary(null);
}