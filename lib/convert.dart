import 'dart:collection';
import 'dart:convert';

import 'package:notus/notus.dart';
import 'package:quill_delta/quill_delta.dart';

import 'src/ast.dart' as ast;

//import 'block_parser.dart';
import 'src/document.dart';

//import 'extension_set.dart';
//import 'inline_parser.dart';

class NotusMarkdownCodec extends Codec<Delta, String> {
  const NotusMarkdownCodec();

  @override
  Converter<String, Delta> get decoder => _NotusMarkdownDecoder();

  @override
  Converter<Delta, String> get encoder => _NotusMarkdownEncoder();
}

class _NotusMarkdownEncoder extends Converter<Delta, String> {
  static const kBold = '**';
  static const kItalic = '_';
  static final kSimpleBlocks = <NotusAttribute, String>{
    NotusAttribute.bq: '> ',
    NotusAttribute.ul: '* ',
    NotusAttribute.ol: '1. ',
  };

  List<NotusAttribute> currentInlineAttributes = <NotusAttribute>[];

  @override
  String convert(Delta input) {
    final iterator = DeltaIterator(input);
    final buffer = StringBuffer();
    final lineBuffer = StringBuffer();
    NotusAttribute<String> currentBlockStyle;
    var currentInlineStyle = NotusStyle();
    final currentBlockLines = [];

    void _handleBlock(NotusAttribute<String> blockStyle) {
      if (currentBlockLines.isEmpty) return;

      // If there was a block before this one, we add an empty line between the blocks.
      if (buffer.isNotEmpty) buffer.writeln();

      if (blockStyle == null) {
        // This is a regular text paragraph
        buffer.write(currentBlockLines.join('\n'));
        buffer.writeln();
      } else if (blockStyle == NotusAttribute.code) {
        _writeAttribute(buffer, blockStyle);
        buffer.write(currentBlockLines.join('\n'));
        _writeAttribute(buffer, blockStyle, close: true);
        buffer.writeln();
      } else {
        // Dealing with lists or a quote.
        for (var line in currentBlockLines) {
          _writeBlockTag(buffer, blockStyle);
          buffer.write(line);
          buffer.writeln();
        }
      }
    }

    void _handleSpan(String text, Map<String, dynamic> attributes) {
      final style = NotusStyle.fromJson(attributes);
      currentInlineStyle = _writeInline(lineBuffer, text, style, currentInlineStyle);
    }

    void _handleLine(Map<String, dynamic> attributes) {
      //if (lineBuffer.isEmpty) return;
      final style = NotusStyle.fromJson(attributes);
      final lineBlock = style.get(NotusAttribute.block);
      if (lineBlock == currentBlockStyle) {
        currentBlockLines.add(_writeLine(lineBuffer.toString(), style));
      } else {
        _handleBlock(currentBlockStyle);
        currentBlockLines.clear();
        currentBlockLines.add(_writeLine(lineBuffer.toString(), style));

        currentBlockStyle = lineBlock;
      }
      lineBuffer.clear();
    }

    while (iterator.hasNext) {
      final op = iterator.next();
      final lf = op.data.indexOf('\n');
      if (lf == -1) {
        _handleSpan(op.data, op.attributes);
      } else {
        var span = StringBuffer();
        for (var i = 0; i < op.data.length; i++) {
          if (op.data.codeUnitAt(i) == 0x0A) {
            if (span.isNotEmpty) {
              // Write the span if it's not empty.
              _handleSpan(span.toString(), op.attributes);
            }
            // Close any open inline styles.
            _handleSpan('', null);
            _handleLine(op.attributes);
            span.clear();
          } else {
            span.writeCharCode(op.data.codeUnitAt(i));
          }
        }
        // Remaining span
        if (span.isNotEmpty) {
          _handleSpan(span.toString(), op.attributes);
        }
      }
    }
    _handleBlock(currentBlockStyle); // Close the last block
    return buffer.toString();
  }

  String _writeLine(String text, NotusStyle style) {
    final buffer = StringBuffer();
    if (style.contains(NotusAttribute.heading)) {
      _writeAttribute(buffer, style.get<int>(NotusAttribute.heading));
    }

    // Write the text itself
    buffer.write(text);
    return buffer.toString();
  }

  String _trimRight(StringBuffer buffer) {
    final text = buffer.toString();
    if (!text.endsWith(' ')) return '';
    final result = text.trimRight();
    buffer.clear();
    buffer.write(result);
    return ' ' * (text.length - result.length);
  }

  NotusStyle _writeInline(StringBuffer buffer, String text, NotusStyle style, NotusStyle currentStyle) {
    // First close any current styles if needed
    final markedForRemoval = <NotusAttribute>[];
    for (var value in currentInlineAttributes.reversed) {
      if (value.scope == NotusAttributeScope.line) continue;
      if (style.containsSame(value)) continue;
      final padding = _trimRight(buffer);
      _writeAttribute(buffer, value, close: true);
      if (padding.isNotEmpty) buffer.write(padding);
      markedForRemoval.add(value);
    }

    // Make sure to remove all attributes that are marked for removal.
    for (final value in markedForRemoval) {
      currentInlineAttributes.remove(value);
    }

    // Now open any new styles.
    for (var value in style.values) {
      if (value.scope == NotusAttributeScope.line) continue;
      if (currentStyle.containsSame(value)) continue;
      final originalText = text;
      text = text.trimLeft();
      final padding = ' ' * (originalText.length - text.length);
      if (padding.isNotEmpty) buffer.write(padding);
      _writeAttribute(buffer, value);
    }
    // Write the text itself
    buffer.write(text);
    return style;
  }

  void _writeAttribute(StringBuffer buffer, NotusAttribute attribute, {bool close = false}) {
    if (attribute == NotusAttribute.bold) {
      _writeBoldTag(buffer);
    } else if (attribute == NotusAttribute.italic) {
      _writeItalicTag(buffer);
    } else if (attribute.key == NotusAttribute.link.key) {
      _writeLinkTag(buffer, attribute as NotusAttribute<String>, close: close);
    } else if (attribute.key == NotusAttribute.heading.key) {
      _writeHeadingTag(buffer, attribute as NotusAttribute<int>);
    } else if (attribute.key == NotusAttribute.block.key) {
      _writeBlockTag(buffer, attribute as NotusAttribute<String>, close: close);
    } else {
      throw ArgumentError('Cannot handle $attribute');
    }
    if (!close) {
      currentInlineAttributes.add(attribute);
    }
  }

  void _writeBoldTag(StringBuffer buffer) {
    buffer.write(kBold);
  }

  void _writeItalicTag(StringBuffer buffer) {
    buffer.write(kItalic);
  }

  void _writeLinkTag(StringBuffer buffer, NotusAttribute<String> link, {bool close = false}) {
    if (close) {
      buffer.write('](${link.value})');
    } else {
      buffer.write('[');
    }
  }

  void _writeHeadingTag(StringBuffer buffer, NotusAttribute<int> heading) {
    var level = heading.value;
    buffer.write('#' * level + ' ');
  }

  void _writeBlockTag(StringBuffer buffer, NotusAttribute<String> block, {bool close = false}) {
    if (block == NotusAttribute.code) {
      if (close) {
        buffer.write('\n```');
      } else {
        buffer.write('```\n');
      }
    } else {
      if (close) return; // no close tag needed for simple blocks.

      final tag = kSimpleBlocks[block];
      buffer.write(tag);
    }
  }
}

class _NotusMarkdownDecoder extends Converter<String, Delta> {
  static const kBold = '**';
  static const kItalic = '_';
  static final kSimpleBlocks = <NotusAttribute, String>{
    NotusAttribute.bq: '> ',
    NotusAttribute.ul: '* ',
    NotusAttribute.ol: '1. ',
  };

  @override
  Delta convert(String markdown) {
    var document = Document();
    var lines = markdown.replaceAll('\r\n', '\n').split('\n');
    return convertToNotus(document.parseLines(lines));
    // TODO: Add one more line-ending
  }
}

Delta convertToNotus(List<ast.Node> nodes) => NotusConverter().convert(nodes);

class NotusConverter implements ast.NodeVisitor {
  static final _blockTags = RegExp('h1|h2|h3|h4|h5|h6|hr|pre|ul|ol|blockquote|p|pre');

  Delta delta;

  Queue<NotusAttribute> activeInlineAttributes;

  NotusAttribute activeBlockAttribute;

  Set<String> uniqueIds;

  ast.Element previousElement;

  ast.Element previousToplevelElement;

  NotusConverter();

  Delta convert(List<ast.Node> nodes) {
    delta = Delta();
    activeInlineAttributes = Queue<NotusAttribute>();
    uniqueIds = LinkedHashSet<String>();

    for (final node in nodes) node.accept(this);

    delta.insert('\n', activeBlockAttribute?.toJson());
    return delta;
  }

  void visitText(ast.Text text) {
    // Remove trailing newline
    //final lines = text.text.trim().split('\n');

    /*
    final attributes = Map<String, dynamic>();
    for (final attr in activeInlineAttributes) {
      attributes.addAll(attr.toJson());
    }

    for (final l in lines) {
      delta.insert(l, attributes);
      delta.insert('\n', activeBlockAttribute.toJson());
    }*/

    var str = text.text;
    if (str.endsWith('\n')) str = str.substring(0, str.length - 1);

    final attributes = Map<String, dynamic>();
    for (final attr in activeInlineAttributes) {
      attributes.addAll(attr.toJson());
    }

    var newlineIndex = str.indexOf('\n');
    var startIndex = 0;
    while (newlineIndex != -1) {
      final previousText = str.substring(startIndex, newlineIndex);
      if (previousText.isNotEmpty) delta.insert(previousText, attributes);
      delta.insert('\n', activeBlockAttribute?.toJson());

      startIndex = newlineIndex + 1;
      newlineIndex = str.indexOf('\n', newlineIndex + 1);
    }

    if (startIndex < str.length) {
      final lastStr = str.substring(startIndex);
      delta.insert(lastStr, attributes);
    }


    /*if (activeBlockAttribute != null) {
      final lines = text.text.trim().split('\n');
      for (var l in lines) {
        delta.insert(l, attributes);
        delta.insert('\n', activeBlockAttribute.toJson());
      }
    } else {
      delta.insert(text.text, attributes);
    }*/
  }

  bool visitElementBefore(ast.Element element) {


    // Hackish. Separate block-level elements with newlines.
    final attr = _tagToNotusAttribute(element.tag);

    if (delta.isNotEmpty && _blockTags.firstMatch(element.tag) != null) {
      if (element.isToplevel) {
        // Finish off the last top level block.
        delta.insert('\n', activeBlockAttribute?.toJson());

        // Only separate the blocks if both are paragraphs.
        if (previousToplevelElement != null && previousToplevelElement.tag == 'p' && element.tag == 'p') {
          delta.insert('\n');
        }
      } else if (element.tag == 'p' && previousElement != null && !previousElement.isToplevel) {
        // Finish off the last lower-level block.
        delta.insert('\n', activeBlockAttribute?.toJson());

        // Add an empty line between the lower-level blocks.
        delta.insert('\n', activeBlockAttribute?.toJson());
      }
    }

    // Keep track of the top-level block attribute.
    if (element.isToplevel) activeBlockAttribute = attr;

    if (_blockTags.firstMatch(element.tag) == null && attr != null) {
      activeInlineAttributes.addLast(attr);
    }

    // Sort the keys so that we generate stable output.
    //var attributeNames = element.attributes.keys.toList();
    //attributeNames.sort((a, b) => a.compareTo(b));

    //for (var name in attributeNames) {
    //buffer.write(' $name="${element.attributes[name]}"');
    //}

    // attach header anchor ids generated from text
    //if (element.generatedId != null) {
    //buffer.write(' id="${uniquifyId(element.generatedId)}"');
    //}

    previousElement = element;
    if (element.isToplevel) previousToplevelElement = element;

    if (element.isEmpty) {
      // Empty element like <hr/>.
      //buffer.write(' />');

      if (element.tag == 'br') {
        //buffer.write('\n');
      }

      return false;
    } else {
      //buffer.write('>');
      return true;
    }
  }

  void visitElementAfter(ast.Element element) {
    /*if (_isParagraph(element)) {
      delta.insert('\n\n', Map<String, dynamic>());
      return;
    }*/

    final attr = _tagToNotusAttribute(element.tag);
    if (attr == null || !attr.isInline || activeInlineAttributes.last != attr) return;
    activeInlineAttributes.removeLast();
  }

  /// Uniquifies an id generated from text.
  String uniquifyId(String id) {
    if (!uniqueIds.contains(id)) {
      uniqueIds.add(id);
      return id;
    }

    var suffix = 2;
    var suffixedId = '$id-$suffix';
    while (uniqueIds.contains(suffixedId)) {
      suffixedId = '$id-${suffix++}';
    }
    uniqueIds.add(suffixedId);
    return suffixedId;
  }

  NotusAttribute _tagToNotusAttribute(String tag) {
    switch (tag) {
      case 'em':
        return NotusAttribute.italic;
      case 'strong':
        return NotusAttribute.bold;
      case 'ul':
        return NotusAttribute.ul;
      case 'ol':
        return NotusAttribute.ol;
      case 'pre':
        return NotusAttribute.code;
      case 'blockquote':
        return NotusAttribute.bq;
    }

    return null;
  }
}
