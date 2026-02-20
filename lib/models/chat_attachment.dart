class ChatAttachment {
  final String fileName;
  final String mimeType;
  final String base64Data;
  final int bytes;
  final String? localPath;

  const ChatAttachment({
    required this.fileName,
    required this.mimeType,
    required this.base64Data,
    required this.bytes,
    this.localPath,
  });

  bool get isImage => mimeType.startsWith('image/');

  Map<String, dynamic> toRpcMap() {
    return {
      'type': isImage ? 'image' : 'file',
      'mimeType': mimeType,
      'fileName': fileName,
      'content': base64Data,
    };
  }
}
