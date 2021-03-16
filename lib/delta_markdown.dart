library delta_markdown;

import 'dart:convert';

import 'package:flutter_quill/models/quill_delta.dart';

import 'src/delta_markdown_decoder.dart';
import 'src/delta_markdown_encoder.dart';

class DeltaMarkdownCodec extends Codec<Delta, String> {
  const DeltaMarkdownCodec();

  @override
  Converter<String, Delta> get decoder => DeltaMarkdownDecoder();

  @override
  Converter<Delta, String> get encoder => DeltaMarkdownEncoder();
}
