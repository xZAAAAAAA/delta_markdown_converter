import 'package:test/test.dart';
import 'package:notus/notus.dart';
import 'package:quill_delta/quill_delta.dart';

import 'convert.dart';


void main() {
  final c = NotusMarkdownCodec();
  final emptyAttr = Map<String, dynamic>();

  final codeAttr = Map<String, dynamic>();
  codeAttr.addAll(NotusAttribute.code.toJson());

  final ulAttr = Map<String, dynamic>();
  ulAttr.addAll(NotusAttribute.ul.toJson());

  final olAttr = Map<String, dynamic>();
  olAttr.addAll(NotusAttribute.ol.toJson());

  final italicAttr = Map<String, dynamic>();
  italicAttr.addAll(NotusAttribute.italic.toJson());

  final boldAttr = Map<String, dynamic>();
  boldAttr.addAll(NotusAttribute.bold.toJson());

  final heading1Attr = Map<String, dynamic>();
  heading1Attr.addAll(NotusAttribute.heading.level1.toJson());

  final heading2Attr = Map<String, dynamic>();
  heading2Attr.addAll(NotusAttribute.heading.level2.toJson());

  final heading3Attr = Map<String, dynamic>();
  heading3Attr.addAll(NotusAttribute.heading.level3.toJson());

  test('Separated single-line unordered lists', () {
    final str =
"""
* UL item 1

* UL item 2
""";

    final res = c.decode(str);

    final expected = Delta();
    expected.insert('UL item 1', emptyAttr);
    expected.insert('\n', ulAttr);
    expected.insert('UL item 2', emptyAttr);
    expected.insert('\n', ulAttr);

    expect(res, expected);
  });

  test('Inline style in numbered lists', () {
    final str =
"""
1. OL item 1
1. _OL item 2_
""";

    final res = c.decode(str);

    final expected = Delta();
    expected.insert('OL item 1', emptyAttr);
    expected.insert('\n', olAttr);
    expected.insert('OL item 2', italicAttr);
    expected.insert('\n', olAttr);

    expect(res, expected);
  });


  test('List and paragraph with inline styles.', () {
    final str =
    """
1. OL item 1

_Italic_**Bold**
""";

    final res = c.decode(str);

    final expected = Delta();
    expected.insert('OL item 1', emptyAttr);
    expected.insert('\n', olAttr);
    expected.insert('Italic', italicAttr);
    expected.insert('Bold', boldAttr);
    expected.insert('\n');

    expect(res, expected);
  });


  test('Multiple empty lines are removed', () {
    final str =
    """
Paragraph one.



Paragraph two.
""";

    final res = c.decode(str);

    final expected = Delta();
    expected.insert('Paragraph one.', emptyAttr);
    expected.insert('\n');
    expected.insert('Paragraph two.', emptyAttr);
    expected.insert('\n');

    expect(res, expected);
  });

  test('Inline styles in a list', () {
    final str =
    """
* regular and *italic* text
* regular and **bold** text
""";

    final res = c.decode(str);

    final expected = Delta();
    expected.insert('regular and ', emptyAttr);
    expected.insert('italic', italicAttr);
    expected.insert(' text', emptyAttr);
    expected.insert('\n', ulAttr);
    expected.insert('regular and ', emptyAttr);
    expected.insert('bold', boldAttr);
    expected.insert(' text', emptyAttr);
    expected.insert('\n', ulAttr);

    expect(res, expected);
  });

  test('Handles headings', () {
    final str =
    """
### heading 3
paragraph
""";

    final res = c.decode(str);

    final expected = Delta();
    expected.insert('heading 3', emptyAttr);
    expected.insert('\n', heading3Attr);
    expected.insert('paragraph', emptyAttr);
    expected.insert('\n');

    expect(res, expected);
  });

  test('Handles headings with inline styles', () {
    final str =
    """
# *heading 1*
""";

    final res = c.decode(str);

    final expected = Delta();
    expected.insert('heading 1', italicAttr);
    expected.insert('\n', heading1Attr);

    expect(res, expected);
  });

  test('Ignores block and inline markdown inside of a code block', () {
    final str =
    """
```
# Not a real heading 1
*Not italic*
```
""";

    final res = c.decode(str);

    final expected = Delta();
    expected.insert('# Not a real heading 1', emptyAttr);
    expected.insert('\n', codeAttr);
    expected.insert('*Not italic*', emptyAttr);
    expected.insert('\n', codeAttr);

    expect(res, expected);
  });

}