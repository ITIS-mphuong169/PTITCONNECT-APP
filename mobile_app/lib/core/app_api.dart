class AppApi {
  AppApi._();

  static const String host = 'http://127.0.0.1:8000';
  static const String users = '$host/api/users';
  static const String community = '$host/api/community';
  static const String documents = '$host/api/documents';
  static const String groups = '$host/api/groups';
  static const String chat = '$host/api/chat';
  static const String notifications = '$host/api/notifications';
}
