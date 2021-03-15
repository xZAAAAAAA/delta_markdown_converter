import 'package:flutter_quill/models/documents/attribute.dart';
import 'package:flutter_quill/models/quill_delta.dart';
import 'package:delta_markdown/delta_markdown.dart';
import 'package:test/test.dart';

void main() {
  const c = DeltaMarkdownCodec();

  final codeAttr = <String, dynamic>{}..addAll(Attribute.codeBlock.toJson());

  final ulAttr = <String, dynamic>{}..addAll(Attribute.ul.toJson());

  final olAttr = <String, dynamic>{}..addAll(Attribute.ol.toJson());

  final italicAttr = <String, dynamic>{}..addAll(Attribute.italic.toJson());

  final boldAttr = <String, dynamic>{}..addAll(Attribute.bold.toJson());

  final heading1Attr = <String, dynamic>{}..addAll(Attribute.h1.toJson());

  // final heading2Attr = <String, dynamic>{}..addAll(Attribute.h2.toJson());

  final heading3Attr = <String, dynamic>{}..addAll(Attribute.h3.toJson());

  test('Expect two inserts from one given markdown line', () {
    const str = 'Test';
    final expected = Delta()..insert('Test')..insert('\n');

    final result = c.decode(str);

    expect(result, expected);
  });

  test('Separated single-line unordered lists', () {
    const str = '''
* UL item 1

* UL item 2
''';

    final result = c.decode(str);

    final expected = Delta()
      ..insert(
        'UL item 1',
      )
      ..insert('\n', ulAttr)
      ..insert('UL item 2')
      ..insert('\n', ulAttr);

    expect(result, expected);
  });

  test('Inline style in numbered lists', () {
    const str = '''
1. OL item 1
1. _OL item 2_
''';

    final res = c.decode(str);

    final expected = Delta()
      ..insert('OL item 1')
      ..insert('\n', olAttr)
      ..insert('OL item 2', italicAttr)
      ..insert('\n', olAttr);

    expect(res, expected);
  });

  test('List and paragraph with inline styles.', () {
    const str = '''
1. OL item 1

_Italic_**Bold**
''';

    final res = c.decode(str);

    final expected = Delta()
      ..insert('OL item 1')
      ..insert('\n', olAttr)
      ..insert('Italic', italicAttr)
      ..insert('Bold', boldAttr)
      ..insert('\n');

    expect(res, expected);
  });

  test('Multiple empty lines are removed', () {
    const str = '''
Paragraph one.



Paragraph two.
''';

    final res = c.decode(str);

    final expected = Delta()
      ..insert('Paragraph one.')
      ..insert('\n')
      ..insert('Paragraph two.')
      ..insert('\n');

    expect(res, expected);
  });

  test('Inline styles in a list', () {
    const str = '''
* regular and *italic* text
* regular and **bold** text
''';

    final res = c.decode(str);

    final expected = Delta()
      ..insert('regular and ')
      ..insert('italic', italicAttr)
      ..insert(' text')
      ..insert('\n', ulAttr)
      ..insert('regular and ')
      ..insert('bold', boldAttr)
      ..insert(' text')
      ..insert('\n', ulAttr);

    expect(res, expected);
  });

  test('Handles headings', () {
    const str = '''
### heading 3
paragraph
''';

    final res = c.decode(str);

    final expected = Delta()
      ..insert('heading 3')
      ..insert('\n', heading3Attr)
      ..insert('paragraph')
      ..insert('\n');

    expect(res, expected);
  });

  test('Handles headings with inline styles', () {
    const str = '''
# *heading 1*
''';

    final res = c.decode(str);

    final expected = Delta()
      ..insert('heading 1', italicAttr)
      ..insert('\n', heading1Attr);

    expect(res, expected);
  });

  test('Ignores block and inline markdown inside of a code block', () {
    const str = '''
```
# Not a real heading 1
*Not italic*
```
''';

    final res = c.decode(str);

    final expected = Delta()
      ..insert('# Not a real heading 1')
      ..insert('\n', codeAttr)
      ..insert('*Not italic*')
      ..insert('\n', codeAttr);

    expect(res, expected);
  });

  test('Handles links', () {
    const str = '''
[Space](https://getspace.app)
''';

    final res = c.decode(str);

    final linkAttr = <String, dynamic>{}
      ..addAll(LinkAttribute('https://getspace.app').toJson());

    final expected = Delta()..insert('Space', linkAttr)..insert('\n');

    expect(res, expected);
  });

  test('Handle image', () {
    const str = '''
![](image.jpg)
''';
    final imageAttr = {'image': 'image.jpg'};
    final expected = Delta()..insert(imageAttr)..insert('\n');
    // Operation (insert⟨ {image: http://localhost/cb54dcd0-8501-11eb-8242-b34ccc3b8954.png} ⟩)
    // "[{"insert":{"image":"http://localhost/cb54dcd0-8501-11eb-8242-b34ccc3b8954.png"}},{"insert":"\n\n"}]"
    final res = c.decode(str);

    expect(res, expected);
  });
}
