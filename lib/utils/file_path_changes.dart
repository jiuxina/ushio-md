import 'package:path/path.dart' as p;

/// Canonical keys for file-list selections and boundary-aware path remapping.
String normalizedFilePath(String path) => p.normalize(p.absolute(path));

bool isPathWithin(String path, String ancestor) {
  final normalized = normalizedFilePath(path);
  final root = normalizedFilePath(ancestor);
  return p.equals(normalized, root) || p.isWithin(root, normalized);
}

String? applyFilePathChanges(String path, Map<String, String?> changes) {
  for (final entry in changes.entries) {
    if (!isPathWithin(path, entry.key)) continue;
    final destination = entry.value;
    if (destination == null) return null;
    final relative = p.relative(
      normalizedFilePath(path),
      from: normalizedFilePath(entry.key),
    );
    return relative == '.'
        ? normalizedFilePath(destination)
        : p.join(normalizedFilePath(destination), relative);
  }
  return path;
}
