class SessionExpiredException implements Exception {
  final String message;

  const SessionExpiredException([
    this.message = 'Сессия истекла. Войдите снова.',
  ]);

  @override
  String toString() => message;
}
