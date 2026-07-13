bool? rawTranscriptVisibilityForCommand({
  required bool current,
  required String arguments,
}) {
  final normalized = arguments.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'toggle') {
    return !current;
  }
  if (normalized == 'on' || normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'off' || normalized == 'false' || normalized == '0') {
    return false;
  }
  return null;
}
