enum MessageType { user, ai }

class Message {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isLoading;
  final List<String> imagePaths;

  Message({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isLoading = false,
    this.imagePaths = const [],
  });
}

class Conversation {
  final String id;
  final String title;
  final DateTime lastUpdated;
  final List<Message> messages;

  Conversation({
    required this.id,
    required this.title,
    required this.lastUpdated,
    this.messages = const [],
  });
}
