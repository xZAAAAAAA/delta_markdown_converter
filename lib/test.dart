import 'package:test/test.dart';
import 'package:notus/notus.dart';
import 'package:quill_delta/quill_delta.dart';

import 'convert.dart';


void main() {
  final c = NotusMarkdownCodec();
  final emptyAttr = Map<String, dynamic>();

  final ulAttr = Map<String, dynamic>();
  ulAttr.addAll(NotusAttribute.ul.toJson());

  final olAttr = Map<String, dynamic>();
  olAttr.addAll(NotusAttribute.ol.toJson());

  final italicAttr = Map<String, dynamic>();
  italicAttr.addAll(NotusAttribute.italic.toJson());

  final boldAttr = Map<String, dynamic>();
  boldAttr.addAll(NotusAttribute.bold.toJson());

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


  test('', () {
    final str =
    """
* regular and *italic* text
""";

    final res = c.decode(str);

    final expected = Delta();
    expected.insert('regular and ', emptyAttr);
    expected.insert('italic', italicAttr);
    expected.insert(' text', emptyAttr);
    expected.insert('\n', ulAttr);

    expect(res, expected);
  });

}