A portable Markdown library written in Dart.
It can convert between Markdown and Delta.

### Usage

```dart
import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter_quill/models/quill_delta.dart';

void main() {
  const markdown = 'Hello **Markdown**';
  print(markdownToDelta(markdown));
  // insert⟨ Hello  ⟩
  // insert⟨ Markdown ⟩ + {bold: true}
  // insert⟨ ⏎ ⟩

  final delta = Delta()
    ..insert('Hello ')
    ..insert('Markdown', {'bold': true})
    ..insert('\n');
  print(deltaToMarkdown(delta));
  // Hello **Markdown**
}
```