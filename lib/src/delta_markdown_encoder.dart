import 'dart:convert';

import 'package:flutter_quill/models/documents/attribute.dart';
import 'package:flutter_quill/models/documents/nodes/embed.dart';
import 'package:flutter_quill/models/documents/style.dart';
import 'package:flutter_quill/models/quill_delta.dart';

class DeltaMarkdownEncoder extends Converter<Delta, String> {
  static const _lineFeedAsciiCode = 0x0A;

  static const kBold = 'strong';
  static const kItalic = 'em';
  static final kSimpleBlocks = <Attribute, String>{
    Attribute.blockQuote: 'blockquote',
    Attribute.ul: 'ul',
    Attribute.ol: 'ol',
  };

  StringBuffer markdown;
  StringBuffer lineBuffer;

  Attribute<String> currentBlockStyle;
  Style currentInlineStyle;

  List<String> currentBlockLines;

  /// Converts the [input] delta to Markdown.
  @override
  String convert(Delta input) {
    // Iterates through all operations of the delta.
    final iterator = DeltaIterator(input);

    markdown = StringBuffer();
    lineBuffer = StringBuffer();

    currentInlineStyle = Style();

    currentBlockLines = <String>[];

    while (iterator.hasNext) {
      final operation = iterator.next();
      final operationData = operation.data as String; // Hope this is a String

      final lineFeedPosition = operationData.indexOf('\n');
      final containsLinefeed = lineFeedPosition != -1;

      if (containsLinefeed) {
        _handleInline(operationData, operation.attributes);
      } else {
        final span = StringBuffer();

        for (var i = 0; i < operationData.length; i++) {
          if (operationData.codeUnitAt(i) == _lineFeedAsciiCode) {
            if (span.isNotEmpty) {
              // Write the span if it's not empty.
              _handleInline(span.toString(), operation.attributes);
            }
            // Close any open inline styles.
            _handleInline('', null);
            _handleLine(operation.attributes);
            span.clear();
          } else {
            span.writeCharCode(operationData.codeUnitAt(i));
          }
        }

        // Remaining span
        if (span.isNotEmpty) {
          _handleInline(span.toString(), operation.attributes);
        }
      }
    }

    _handleBlock(currentBlockStyle); // Close the last block

    return markdown.toString().replaceAll('\n', '<br>');
  }

  void _handleInline(String text, Map<String, dynamic> attributes) {
    final style = Style.fromJson(attributes);

    Attribute wasA;
    // First close any current styles if needed
    for (final value in currentInlineStyle.attributes.values) {
      if (value.scope == AttributeScope.INLINE) {
        continue;
      }
      if (value.key == 'a') {
        wasA = value;
        continue;
      }
      if (style.containsKey(value.key)) {
        continue;
      }

      final padding = _trimRight(lineBuffer);
      _writeAttribute(lineBuffer, value, close: true);
      if (padding.isNotEmpty) {
        lineBuffer.write(padding);
      }
    }

    if (wasA != null) {
      _writeAttribute(lineBuffer, wasA, close: true);
    }

    // Now open any new styles.
    for (final attribute in style.attributes.values) {
      if (attribute.scope == AttributeScope.INLINE) {
        continue;
      }
      if (currentInlineStyle.containsKey(attribute.key)) {
        continue;
      }
      final originalText = text;
      text = text.trimLeft();
      final padding = ' ' * (originalText.length - text.length);
      if (padding.isNotEmpty) {
        lineBuffer.write(padding);
      }
      _writeAttribute(lineBuffer, attribute);
    }

    // Write the text itself
    lineBuffer.write(text);
    currentInlineStyle = style;
  }

  void _handleLine(Map<String, dynamic> attributes) {
    final style = Style.fromJson(attributes);
    final lineBlock =
        style.attributes[Attribute.blockQuote] as Attribute<String>;
    if (lineBlock == currentBlockStyle) {
      currentBlockLines.add(_writeLine(lineBuffer.toString(), style));
    } else {
      _handleBlock(currentBlockStyle);
      currentBlockLines
        ..clear()
        ..add(_writeLine(lineBuffer.toString(), style));

      currentBlockStyle = lineBlock;
    }
    lineBuffer.clear();
  }

  void _handleBlock(Attribute blockStyle) {
    if (currentBlockLines.isEmpty) {
      return; // Empty block
    }

    if (blockStyle == null) {
      markdown
        ..write(currentBlockLines.join('\n\n'))
        ..writeln();
    } else if (blockStyle == Attribute.codeBlock) {
      _writeAttribute(markdown, blockStyle);
      markdown.write(currentBlockLines.join('\n'));
      _writeAttribute(markdown, blockStyle, close: true);
      markdown.writeln();
    } else if (blockStyle == Attribute.blockQuote) {
      _writeAttribute(markdown, blockStyle);
      markdown.write(currentBlockLines.join('\n'));
      _writeAttribute(markdown, blockStyle, close: true);
      markdown.writeln();
    } else if (blockStyle == Attribute.ol || blockStyle == Attribute.ul) {
      _writeAttribute(markdown, blockStyle);
      markdown
        ..write('<li>')
        ..write(currentBlockLines.join('</li><li>'))
        ..write('</li>');
      _writeAttribute(markdown, blockStyle, close: true);
      markdown.writeln();
    } else {
      for (final line in currentBlockLines) {
        _writeBlockTag(markdown, blockStyle);
        markdown
          ..write(line)
          ..writeln();
      }
    }
    markdown.writeln();
  }

  String _writeLine(String text, Style style) {
    final buffer = StringBuffer();
    // Open heading
    // if (style.containsKey(Attribute.heading)) { // <- We don't have heading?
    //   _writeAttribute(buffer, style.get<int>(Attribute.heading));
    // }
    // Write the text itself
    // ignore: cascade_invocations
    buffer.write(text);
    // Close the heading
    // if (style.contains(Attribute.heading)) { // <- We don't have heading?
    // ignore: lines_longer_than_80_chars
    //   _writeAttribute(buffer, style.get<int>(Attribute.heading), close: true);
    // }
    return buffer.toString();
  }

  String _trimRight(StringBuffer buffer) {
    final text = buffer.toString();
    if (!text.endsWith(' ')) {
      return '';
    }

    final result = text.trimRight();
    buffer
      ..clear()
      ..write(result);
    return ' ' * (text.length - result.length);
  }

  void _writeAttribute(StringBuffer buffer, Attribute attribute,
      {bool close = false}) {
    if (attribute == Attribute.bold) {
      buffer.write(!close ? '<$kBold>' : '</$kBold>');
    } else if (attribute == Attribute.italic) {
      buffer.write(!close ? '<$kItalic>' : '</$kItalic>');
    } else if (attribute.key == Attribute.link.key) {
      buffer.write(!close
          ? '<a href="${(attribute as Attribute<String>).value}">'
          : '</a>');
      // ignore: lines_longer_than_80_chars
      // } else if (attribute.key == Attribute.heading.key) { //<- We don't have heading
      // buffer.write(!close ? '<h${attribute.value}>' : '</h${attribute.value}>');
      // } else if (attribute.key == Attribute.block.key) {
      // _writeBlockTag(buffer, attribute as Attribute<String>, close: close);
      // } else if (attribute.key == Attribute.embed.key) {
      // _writeEmbedTag(buffer, attribute as EmbedAttribute, close: close);
    } else {
      throw ArgumentError('Cannot handle $attribute');
    }
  }

  void _writeBlockTag(StringBuffer buffer, Attribute block,
      {bool close = false}) {
    if (block == Attribute.codeBlock) {
      buffer.write(!close ? '\n<code>' : '</code>\n');
    } else {
      buffer.write(
          !close ? '<${kSimpleBlocks[block]}>' : '</${kSimpleBlocks[block]}>');
    }
  }

  void _writeEmbedTag(StringBuffer buffer, BlockEmbed embed,
      {bool close = false}) {
    if (close) {
      return;
    }

    if (embed.type == BlockEmbed.horizontalRule.type) {
      buffer.write('<hr>');
    } else if (embed.type == BlockEmbed.image('').type) {
      buffer.write('<img src="${embed.data}">');
    }
  }
}
