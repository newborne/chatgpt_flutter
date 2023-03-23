import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() {
  timeago.setLocaleMessages('en', timeago.EnMessages());
  runApp(ChatApp());
}

class ChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chat App',
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  List<ChatMessage> _messages = [];

  String _openaiApiKey = "";

  void _handleOpenaiApiKey(String apiKey) {
    setState(() {
      _openaiApiKey = apiKey;
    });
  }

  void _handleSubmitted(String text) async {
    if (_openaiApiKey == "") {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Openai API Key not set"),
            content: Text("Please set the Openai API Key"),
            actions: [
              TextButton(
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        },
      );
      return;
    }

    _textController.clear();
    ChatMessage message = ChatMessage(
      text: text,
      isMe: true,
      time: DateTime.now(),
    );
    setState(() {
      _messages.insert(0, message);
    });

    print("Sending request to Openai");
    var response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openaiApiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {"role": "user", "content": text}
        ]
      }),
    );
    print("Response from Openai: ${response.body}");
    var data = jsonDecode(response.body);
    String botResponse = data['choices'][0]['message']['content'];

    ChatMessage botMessage = ChatMessage(
      text: botResponse,
      isMe: false,
      time: DateTime.now(),
    );
    setState(() {
      _messages.insert(0, botMessage);
    });
  }

  void _handleClear() {
    setState(() {
      _messages = [];
    });
  }

  void _handleSaveImage() async {
    RenderRepaintBoundary boundary =
// ignore: deprecated_member_use
    globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    if (boundary != null) {
      final directory = (await getApplicationDocumentsDirectory()).path;
      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List? pngBytes = byteData?.buffer.asUint8List();
      final filePath = '$directory/chat.png';
      File file = File(filePath);
      await file.writeAsBytes(pngBytes as List<int>);
      final result = await ImageGallerySaver.saveImage(pngBytes!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image saved to gallery'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleShare() async {
    RenderRepaintBoundary boundary =
// ignore: deprecated_member_use
    globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    if (boundary != null) {
      final directory = (await getApplicationDocumentsDirectory()).path;
      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List? pngBytes = byteData?.buffer.asUint8List();
      final filePath = '$directory/chat.png';
      File file = File(filePath);
      await file.writeAsBytes(pngBytes as List<int>);
      Share.shareFiles([filePath], text: 'Chat App');
    }
  }

  GlobalKey globalKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Flutter Chat App"),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              String apiKey = await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("Enter Openai API Key"),
                    content: TextField(
                      onChanged: (value) {
                        _handleOpenaiApiKey(value);
                      },
                    ),
                    actions: [
                      TextButton(
                        child: Text("Done"),
                        onPressed: () {
                          Navigator.of(context).pop(_openaiApiKey);
                        },
                      )
                    ],
                  );
                },
              );
              _handleOpenaiApiKey(apiKey);
            },
          ),
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: _handleClear,
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _handleShare,
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _handleSaveImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              child: RepaintBoundary(
                key: globalKey,
                child: CustomScrollView(
                  reverse: true,
                  slivers: [
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                          return GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _messages[index].text),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Message copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: _messages[index],
                          );
                        },
                        childCount: _messages.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration.collapsed(
                        hintText: "Send a message",
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => _handleSubmitted(_textController.text),
                ),
              ],
            ),
          ),
          Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(vertical: 8.0),
            color: Theme.of(context).primaryColor,
            child: Text(
              "Powered By Newborne",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime time;

  ChatMessage({required this.text, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    final messageContainer = Container(
      margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            timeago.format(time, locale: 'en'),
            style: TextStyle(fontSize: 10.0),
          ),
          Material(
            color: isMe ? Colors.blue : Colors.grey[300],
            borderRadius: BorderRadius.circular(10.0),
            elevation: 6.0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          )
        ],
      ),
    );

    return Row(
      mainAxisAlignment:
      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe) CircleAvatar(child: Icon(Icons.account_circle)),
        messageContainer,
        if (isMe) CircleAvatar(child: Icon(Icons.account_circle)),
      ],
    );
  }
}