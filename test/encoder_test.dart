import 'dart:convert';

import 'package:flutter_quill/models/documents/nodes/embed.dart';
import 'package:flutter_quill/models/quill_delta.dart';
import 'package:delta_markdown/delta_markdown.dart';
import 'package:test/test.dart';

void main() {
  const c = DeltaMarkdownCodec();

  test('Encode an image', () {
    final input = Delta();
    final imageAttr = <String, dynamic>{}
      ..addAll(BlockEmbed.image('image.jpg').toJson());

    input..insert('image', imageAttr)..insert('\n');
    print(jsonEncode(input.toJson()));
    final res = c.encode(input);

    const expected = '''
![image](image.jpg)
''';

    expect(res, expected);
  });
}
