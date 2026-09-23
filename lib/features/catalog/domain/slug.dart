String catalogSlug(String title) {
  final slug = title
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'item' : slug;
}

String uniqueSlug(String base, Set<String> existing) {
  if (!existing.contains(base)) return base;
  var n = 2;
  while (existing.contains('$base-$n')) {
    n++;
  }
  return '$base-$n';
}
