// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/notus_markdown.dart';

void main() {
  final str = """
How **_is_ life?**

Everything is fine here.


```
test
abc
```
> hello
> world
>
> test
> ok
""";

  final converter = NotusMarkdownCodec();
  final res = converter.decode(str);

  final out = converter.encode(res);
  print(out);
  return;
}
