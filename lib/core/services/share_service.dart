import 'package:flutter/services.dart';

class IncomingShare {
  const IncomingShare(this.id, this.text, this.receivedAt);
  final String id, text;
  final DateTime receivedAt;
}

class ShareService {
  static const channel = MethodChannel('reel_reminder/share');
  Future<List<IncomingShare>> pending(String uid) async {
    final result =
        await channel.invokeListMethod<dynamic>('pending', {'uid': uid}) ?? [];
    return result.map((raw) {
      final value = Map<String, dynamic>.from(raw as Map);
      return IncomingShare(
        value['id'] as String,
        value['text'] as String,
        DateTime.fromMillisecondsSinceEpoch(value['time'] as int),
      );
    }).toList();
  }

  Future<void> acknowledge(String id) =>
      channel.invokeMethod('ack', {'id': id});
  Future<void> share(String url) =>
      channel.invokeMethod('share', {'text': url});
  void listen(void Function() onShare) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'incoming') onShare();
    });
  }

  void dispose() => channel.setMethodCallHandler(null);
}
