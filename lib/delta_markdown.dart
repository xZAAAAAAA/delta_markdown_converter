library delta_markdown;

import 'dart:convert';

import 'package:flutter_quill/models/documents/attribute.dart';
import 'package:flutter_quill/models/documents/style.dart';
import 'package:flutter_quill/models/quill_delta.dart';

import 'delta_visitor.dart';
import 'src/document.dart';

class DeltaMarkdownCodec extends Codec<Delta, String> {
  const DeltaMarkdownCodec();

  @override
  Converter<String, Delta> get decoder => _DeltaMarkdownDecoder();

  @override
  Converter<Delta, String> get encoder => _DeltaMarkdownEncoder();
}

class _DeltaMarkdownEncoder extends Converter<Delta, String> {
  static const kBold = 'strong';
  static const kItalic = 'em';
  static final kSimpleBlocks = <Attribute, String>{
    Attribute.blockQuote: 'blockquote',
    Attribute.ul: 'ul',
    Attribute.ol: 'ol',
  };

  @override
  String convert(Delta input) {
    final iterator = DeltaIterator(input);
    final buffer = StringBuffer();
    final lineBuffer = StringBuffer();
    Attribute<String> currentBlockStyle;
    var currentInlineStyle = Style();
    final currentBlockLines = [];

    void _handleBlock(Attribute<String> blockStyle) {
      if (currentBlockLines.isEmpty) {
        return; // Empty block
      }

      if (blockStyle == null) {
        buffer
          ..write(currentBlockLines.join('\n\n'))
          ..writeln();
      } else if (blockStyle == Attribute.codeBlock) {
        _writeAttribute(buffer, blockStyle);
        buffer.write(currentBlockLines.join('\n'));
        _writeAttribute(buffer, blockStyle, close: true);
        buffer.writeln();
      } else if (blockStyle == Attribute.blockQuote) {
        _writeAttribute(buffer, blockStyle);
        buffer.write(currentBlockLines.join('\n'));
        _writeAttribute(buffer, blockStyle, close: true);
        buffer.writeln();
      } else if (blockStyle == Attribute.ol || blockStyle == Attribute.ul) {
        _writeAttribute(buffer, blockStyle);
        buffer
          ..write('<li>')
          ..write(currentBlockLines.join('</li><li>'))
          ..write('</li>');
        _writeAttribute(buffer, blockStyle, close: true);
        buffer.writeln();
      } else {
        for (final line in currentBlockLines) {
          _writeBlockTag(buffer, blockStyle);
          buffer
            ..write(line)
            ..writeln();
        }
      }
      buffer.writeln();
    }

    void _handleSpan(String text, Map<String, dynamic> attributes) {
      final style = Style.fromJson(attributes);
      currentInlineStyle =
          _writeInline(lineBuffer, text, style, currentInlineStyle);
    }

    void _handleLine(Map<String, dynamic> attributes) {
      final style = Style.fromJson(attributes);
      final lineBlock = style.get(Attribute.blockQuote);
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
    return buffer.toString().replaceAll('\n', '<br>');
  }

  String _writeLine(String text, Style style) {
    final buffer = StringBuffer();
    // Open heading
    if (style.contains(Attribute.heading)) {
      _writeAttribute(buffer, style.get<int>(Attribute.heading));
    }
    // Write the text itself
    buffer.write(text);
    // Close the heading
    if (style.contains(Attribute.heading)) {
      _writeAttribute(buffer, style.get<int>(Attribute.heading), close: true);
    }
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

  Style _writeInline(
      StringBuffer buffer, String text, Style style, Style currentStyle) {
    Attribute wasA;
    // First close any current styles if needed
    for (final value in currentStyle.values) {
      if (value.scope == AttributeScope.line) {
        continue;
      }
      if (value.key == 'a') {
        wasA = value;
        continue;
      }
      if (style.containsSame(value)) {
        continue;
      }

      final padding = _trimRight(buffer);
      _writeAttribute(buffer, value, close: true);
      if (padding.isNotEmpty) {
        buffer.write(padding);
      }
    }
    if (wasA != null) {
      _writeAttribute(buffer, wasA, close: true);
    }
    // Now open any new styles.
    for (final value in style.values) {
      if (value.scope == AttributeScope.line) {
        continue;
      }
      if (currentStyle.containsSame(value)) {
        continue;
      }
      final originalText = text;
      text = text.trimLeft();
      final padding = ' ' * (originalText.length - text.length);
      if (padding.isNotEmpty) {
        buffer.write(padding);
      }
      _writeAttribute(buffer, value);
    }
    // Write the text itself
    buffer.write(text);
    return style;
  }

  void _writeAttribute(StringBuffer buffer, Attribute attribute,
      {bool close = false}) {
    if (attribute == Attribute.bold) {
      _writeBoldTag(buffer, close: close);
    } else if (attribute == Attribute.italic) {
      _writeItalicTag(buffer, close: close);
    } else if (attribute.key == Attribute.link.key) {
      _writeLinkTag(buffer, attribute as Attribute<String>, close: close);
    } else if (attribute.key == Attribute.heading.key) {
      _writeHeadingTag(buffer, attribute as Attribute<int>, close: close);
    } else if (attribute.key == Attribute.block.key) {
      _writeBlockTag(buffer, attribute as Attribute<String>, close: close);
    } else if (attribute.key == Attribute.embed.key) {
      _writeEmbedTag(buffer, attribute as EmbedAttribute, close: close);
    } else {
      throw ArgumentError('Cannot handle $attribute');
    }
  }

  void _writeBoldTag(StringBuffer buffer, {bool close = false}) {
    buffer.write(!close ? '<$kBold>' : '</$kBold>');
  }

  void _writeItalicTag(StringBuffer buffer, {bool close = false}) {
    buffer.write(!close ? '<$kItalic>' : '</$kItalic>');
  }

  void _writeLinkTag(StringBuffer buffer, Attribute<String> link,
      {bool close = false}) {
    if (close) {
      buffer.write('</a>');
    } else {
      buffer.write('<a href="${link.value}">');
    }
  }

  void _writeHeadingTag(StringBuffer buffer, Attribute<int> heading,
      {bool close = false}) {
    final level = heading.value;
    buffer.write(!close ? '<h$level>' : '</h$level>');
  }

  void _writeBlockTag(StringBuffer buffer, Attribute<String> block,
      {bool close = false}) {
    if (block == Attribute.codeBlock) {
      if (!close) {
        buffer.write('\n<code>');
      } else {
        buffer.write('</code>\n');
      }
    } else {
      if (!close) {
        buffer.write('<${kSimpleBlocks[block]}>');
      } else {
        buffer.write('</${kSimpleBlocks[block]}>');
      }
    }
  }

  void _writeEmbedTag(StringBuffer buffer, EmbedAttribute embed,
      {bool close = false}) {
    if (close) {
      return;
    }

    if (embed.type == EmbedType.horizontalRule) {
      buffer.write('<hr>');
    } else if (embed.type == EmbedType.image) {
      buffer.write('<img src="${embed.value["source"]}">');
    }
  }
}

class _DeltaMarkdownDecoder extends Converter<String, Delta> {
  @override
  Delta convert(String input) {
    final lines = input.replaceAll('\r\n', '\n').split('\n');

    final markdownDocument = Document().parseLines(lines);

    return DeltaVisitor().convert(markdownDocument);
  }
}
