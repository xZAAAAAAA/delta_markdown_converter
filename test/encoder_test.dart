import 'package:flutter_quill/models/quill_delta.dart';
import 'package:notus_markdown/delta_markdown.dart';
import 'package:test/test.dart';

void main() {
  const c = DeltaMarkdownCodec();
  final emptyAttr = <String, dynamic>{};

  test('Encode an image', () {
    final input = Delta();
    final imageAttr = <String, dynamic>{};
    // imageAttr.addAll(Attribute..image('image.jpg').toJson());

    input..insert('image', imageAttr)..insert('\n', emptyAttr);
    final res = c.encode(input);

    const expected = '''
![image](image.jpg)
''';

    expect(res, expected);
  });
}
