library delta_markdown;

import 'dart:convert';

import 'package:flutter_quill/models/quill_delta.dart';

import 'src/delta_markdown_decoder.dart';
import 'src/delta_markdown_encoder.dart';

/// Codec used to convert between Markdown plain text and Quill deltas.
const DeltaMarkdownCodec _kCodec = DeltaMarkdownCodec();

Delta markdownToDelta(String markdown) {
  return _kCodec.decode(markdown);
}

String deltaToMarkdown(Delta delta) {
  return _kCodec.encode(delta);
}

class DeltaMarkdownCodec extends Codec<Delta, String> {
  const DeltaMarkdownCodec();

  @override
  Converter<String, Delta> get decoder => DeltaMarkdownDecoder();

  @override
  Converter<Delta, String> get encoder => DeltaMarkdownEncoder();
}
