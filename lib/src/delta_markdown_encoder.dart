import 'dart:convert';

import 'package:flutter_quill/models/documents/attribute.dart';
import 'package:flutter_quill/models/documents/nodes/embed.dart';
import 'package:flutter_quill/models/documents/style.dart';
import 'package:flutter_quill/models/quill_delta.dart';

class DeltaMarkdownEncoder extends Converter<Delta, String> {
  static const _lineFeedAsciiCode = 0x0A;

  StringBuffer markdownBuffer;
  StringBuffer lineBuffer;

  Attribute<String> currentBlockStyle;
  Style currentInlineStyle;

  List<String> currentBlockLines;

  /// Converts the [input] delta to Markdown.
  @override
  String convert(Delta input) {
    // Iterates through all operations of the delta.
    final iterator = DeltaIterator(input);

    markdownBuffer = StringBuffer();
    lineBuffer = StringBuffer();

    currentInlineStyle = Style();

    currentBlockLines = <String>[];

    while (iterator.hasNext) {
      final operation = iterator.next();

      if (operation.data is String) {
        final operationData = operation.data as String;

        if (!operationData.contains('\n')) {
          _handleInline(lineBuffer, operationData, operation.attributes);
        } else {
          final span = StringBuffer();

          for (var i = 0; i < operationData.length; i++) {
            if (operationData.codeUnitAt(i) == _lineFeedAsciiCode) {
              if (span.isNotEmpty) {
                // Write the span if it's not empty.
                _handleInline(
                    lineBuffer, span.toString(), operation.attributes);
              }
              // Close any open inline styles.
              _handleInline(lineBuffer, '', null);
              _handleLine(operation.attributes);
              span.clear();
            } else {
              span.writeCharCode(operationData.codeUnitAt(i));
            }
          }

          // Remaining span
          if (span.isNotEmpty) {
            _handleInline(lineBuffer, span.toString(), operation.attributes);
          }
        }
      } else {
        // Embeddable
        final embed = BlockEmbed(
          (operation.data as Map).keys.first as String,
          (operation.data as Map).values.first as String,
        );

        if (embed.type == 'image') {
          _writeEmbedTag(lineBuffer, embed);
          _writeEmbedTag(lineBuffer, embed, close: true);
        }
        /*else if (attribute.key == Attribute.embed.key) {
          _writeEmbedTag(buffer, attribute as EmbedAttribute, close: close);
        }*/
      }
    }

    _handleBlock(currentBlockStyle); // Close the last block

    return markdownBuffer.toString();
  }

  void _handleInline(
      StringBuffer buffer, String text, Map<String, dynamic> attributes) {
    final style = Style.fromJson(attributes);

    // First close any current styles if needed
    final markedForRemoval = <Attribute>[];
    for (final value in currentInlineStyle.attributes.values) {
      // TODO(tillf): Maybe reverse?
      // TODO(tillf): Is block correct?
      if (value.scope == AttributeScope.BLOCK) {
        continue;
      }
      if (style.containsKey(value.key)) {
        continue;
      }

      final padding = _trimRight(buffer);
      _writeAttribute(buffer, value, close: true);
      if (padding.isNotEmpty) {
        buffer.write(padding);
      }
      markedForRemoval.add(value);
    }

    // Make sure to remove all attributes that are marked for removal.
    for (final value in markedForRemoval) {
      currentInlineStyle.attributes.removeWhere((_, v) => v == value);
    }

    // Now open any new styles.
    for (final attribute in style.attributes.values) {
      // TODO(tillf): Is block correct?
      if (attribute.scope == AttributeScope.BLOCK) {
        continue;
      }
      if (currentInlineStyle.containsKey(attribute.key)) {
        continue;
      }
      final originalText = text;
      text = text.trimLeft();
      final padding = ' ' * (originalText.length - text.length);
      if (padding.isNotEmpty) {
        buffer.write(padding);
      }
      _writeAttribute(buffer, attribute);
    }

    // Write the text itself
    buffer.write(text);
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

    // If there was a block before this one, add empty line between the blocks
    if (markdownBuffer.isNotEmpty) {
      markdownBuffer.writeln();
    }

    if (blockStyle == null) {
      markdownBuffer
        ..write(currentBlockLines.join('\n'))
        ..writeln();
    } else if (blockStyle == Attribute.codeBlock) {
      _writeAttribute(markdownBuffer, blockStyle);
      markdownBuffer.write(currentBlockLines.join('\n'));
      _writeAttribute(markdownBuffer, blockStyle, close: true);
      markdownBuffer.writeln();
    } else {
      // Dealing with lists or a quote.
      for (final line in currentBlockLines) {
        _writeBlockTag(markdownBuffer, blockStyle);
        markdownBuffer
          ..write(line)
          ..writeln();
      }
    }
  }

  String _writeLine(String text, Style style) {
    final buffer = StringBuffer();
    // Open heading
    if (style.containsKey(Attribute.h1.key)) {
      _writeAttribute(buffer, Attribute.h1);
    } else if (style.containsKey(Attribute.h2.key)) {
      _writeAttribute(buffer, Attribute.h2);
    } else if (style.containsKey(Attribute.h3.key)) {
      _writeAttribute(buffer, Attribute.h3);
    }

    // Write the text itself
    buffer.write(text);
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

  void _writeAttribute(
    StringBuffer buffer,
    Attribute attribute, {
    bool close = false,
  }) {
    if (attribute.key == Attribute.bold.key) {
      buffer.write('**');
    } else if (attribute.key == Attribute.italic.key) {
      buffer.write('_');
    } else if (attribute.key == Attribute.link.key) {
      buffer.write(!close ? '[' : '](${attribute.value})');
    } else if (attribute.key == Attribute.h1.key) {
      buffer.write('# ');
    } else if (attribute.key == Attribute.h2.key) {
      buffer.write('## ');
    } else if (attribute.key == Attribute.h3.key) {
      buffer.write('### ');
    } else {
      throw ArgumentError('Cannot handle $attribute');
    }
  }

  void _writeBlockTag(
    StringBuffer buffer,
    Attribute block, {
    bool close = false,
  }) {
    if (block == Attribute.codeBlock) {
      buffer.write(!close ? '\n```' : '```\n');
    } else if (block == Attribute.blockQuote) {
      if (close) {
        return; // no close tag needed for simple blocks.
      }

      buffer.write('>');
    } else if (block == Attribute.ul) {
      if (close) {
        return; // no close tag needed for simple blocks.
      }

      buffer.write('*');
    } else if (block == Attribute.ol) {
      if (close) {
        return; // no close tag needed for simple blocks.
      }

      buffer.write('1.');
    } else {
      throw ArgumentError('Cannot handle block $block');
    }
  }

  void _writeEmbedTag(
    StringBuffer buffer,
    BlockEmbed embed, {
    bool close = false,
  }) {
    const kImageType = 'image';
    const kHorizontalRuleType = 'hr';

    if (embed.type == kImageType) {
      if (close) {
        buffer.write('](${embed.data})');
      } else {
        buffer.write('![');
      }
    } else if (embed.type == kHorizontalRuleType && close) {
      buffer.write('\n---\n');
    }
  }
}
