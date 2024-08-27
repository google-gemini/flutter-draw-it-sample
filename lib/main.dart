// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/link.dart';

final wordList = ['STAR', 'HAPPY FACE', 'MOON', 'ARROW', 'DIAMOND', 'SUN'];

void main() {
  runApp(const GenerativeAISample());
}

class GenerativeAISample extends StatelessWidget {
  const GenerativeAISample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gemini Picture Game',
      theme: ThemeData(
        brightness: Brightness.dark,
      ),
      home: const ChatScreen(title: 'Gemini Picture Game'),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? apiKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: switch (apiKey) {
        final providedKey? => ChatWidget(apiKey: providedKey),
        _ => ApiKeyWidget(onSubmitted: (key) {
            setState(() => apiKey = key);
          }),
      },
    );
  }
}

class ApiKeyWidget extends StatelessWidget {
  ApiKeyWidget({required this.onSubmitted, super.key});

  final ValueChanged onSubmitted;
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'To use the Gemini API, you\'ll need an API key. '
              'If you don\'t already have one, '
              'create a key in Google AI Studio.',
            ),
            const SizedBox(height: 8),
            Link(
              uri: Uri.https('aistudio.google.com', '/app/apikey'),
              target: LinkTarget.blank,
              builder: (context, followLink) => TextButton(
                onPressed: followLink,
                child: const Text('Get an API Key'),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration:
                          textFieldDecoration(context, 'Enter your API key'),
                      controller: _textController,
                      onSubmitted: (value) {
                        onSubmitted(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      onSubmitted(_textController.value.text);
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatWidget extends StatefulWidget {
  const ChatWidget({required this.apiKey, super.key});

  final String apiKey;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final dots = <Offset>[];
  final paintKey = GlobalKey();
  late final IdentificationService _service;
  Future<bool>? idResult;
  final _rng = math.Random();
  String secretWord = 'STAR';

  @override
  void initState() {
    super.initState();
    _service = IdentificationService(widget.apiKey);
  }

  Widget _buildIdButton(bool enabled) {
    return ElevatedButton(
      onPressed: !enabled
          ? null
          : () async {
              setState(() => idResult = null);
              final bytes = await _captureWidget();
              setState(() {
                idResult = _service.getId(bytes, secretWord);
              });
            },
      child: const Text('Identify'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox.expand(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 64),
              child: Text('Click/tap and drag in the rectangle below to make an'
                  ' image, and then hit the "Identify" button to send that'
                  ' image to the Gemini API. The multimodal prompt will ask the'
                  ' model to determine if the image and secret word are a'
                  ' match!'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Secret word:  $secretWord',
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: () => setState(() {
                    secretWord = wordList[_rng.nextInt(wordList.length)];
                  }),
                  icon: const Icon(Icons.refresh),
                )
              ],
            ),
            Container(
              width: 400,
              height: 300,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  style: BorderStyle.solid,
                  width: 1.0,
                ),
              ),
              child: RepaintBoundary(
                key: paintKey,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            dots.add(details.localPosition);
                          });
                        },
                      ),
                    ),
                    for (final dot in dots)
                      Positioned(
                        left: dot.dx,
                        top: dot.dy,
                        child: Container(
                          width: 5,
                          height: 5,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (idResult != null)
                  FutureBuilder(
                    future: idResult,
                    builder: (context, snapshot) {
                      return _buildIdButton(snapshot.hasData);
                    },
                  )
                else
                  _buildIdButton(true),
                const SizedBox(width: 32),
                ElevatedButton(
                  onPressed: () => setState(() {
                    dots.clear();
                  }),
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (idResult != null)
              FutureBuilder(
                future: idResult,
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return const StatusWidget('Correct!');
                  } else if (snapshot.data == false) {
                    return const StatusWidget('Not a match.');
                  } else {
                    return const StatusWidget('Thinking...');
                  }
                },
              )
            else
              const StatusWidget(''),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _captureWidget() async {
    final RenderRepaintBoundary boundary =
        paintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final ByteData byteData =
        (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final Uint8List pngBytes = byteData.buffer.asUint8List();
    return pngBytes;
  }
}

class StatusWidget extends StatelessWidget {
  final String status;

  const StatusWidget(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 100,
      child: Center(
        child: Text(
          status,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        ),
      ),
    );
  }
}

InputDecoration textFieldDecoration(BuildContext context, String hintText) =>
    InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );

class IdentificationService {
  final String apiKey;

  late final GenerativeModel model;

  final generationConfig = GenerationConfig(
    temperature: 0.4,
    topK: 32,
    topP: 1,
    maxOutputTokens: 4096,
  );

  final safetySettings = [
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
  ];

  IdentificationService(this.apiKey) {
    model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  }

  Future<bool> getId(Uint8List pngBytes, String symbolName) async {
    final prompt = [
      Content.multi([
        DataPart('image/jpeg', pngBytes),
        TextPart('Does this image contain a $symbolName? Answer "yes" or'
            ' "no" with no additional text.'),
      ]),
    ];

    try {
      final response = await model.generateContent(
        prompt,
        safetySettings: safetySettings,
        generationConfig: generationConfig,
      );
      if (response.text?.toLowerCase().contains('yes') ?? false) {
        return true;
      }
    } on GenerativeAIException {
      return false;
    }

    return false;
  }
}
