import 'dart:convert';

import 'package:flutter_quill/models/quill_delta.dart';
import 'package:delta_markdown/delta_markdown.dart';
import 'package:test/test.dart';

void main() {
  const c = DeltaMarkdownCodec();

  test('Encode three lines with one bold attribute', () {
    final delta = Delta.fromJson(jsonDecode('''
[
  { "insert": "Gandalf", "attributes": { "bold": "true" } },
  { "insert": " the " },
  { "insert": "Grey" },
  { "insert": "\\n" }
]
''') as List<dynamic>);
    const expected = '**Gandalf** the Grey\n';

    final res = c.encode(delta);

    expect(res, expected);
  });

  test('Encode an image', () {
    final delta = Delta.fromJson(jsonDecode('''
[
  {"insert": {"image": "http://image.jpg"}},
  {"insert": "\\n"}
]
''') as List<dynamic>);
    const expected = '''
![](http://image.jpg)
''';

    final res = c.encode(delta);

    expect(res, expected);
  });
}
