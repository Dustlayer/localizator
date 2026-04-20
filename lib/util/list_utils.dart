extension IteratorUtil<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test, {T Function()? orElse}) {
    for (T element in this) {
      if (test(element)) return element;
    }
    if (orElse != null) return orElse();
    return null;
  }
}
