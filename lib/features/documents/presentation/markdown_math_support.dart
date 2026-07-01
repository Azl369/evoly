import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

class MarkdownInlineMathSyntax extends md.InlineSyntax {
  MarkdownInlineMathSyntax() : super(r'\$([^\n$]+?)\$', startCharacter: 36);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match[1]?.trim();
    if (tex == null || tex.isEmpty) {
      return false;
    }

    parser.addNode(md.Element.text(_MarkdownMathTags.inline, tex));
    return true;
  }
}

class MarkdownBlockMathSyntax extends md.BlockSyntax {
  const MarkdownBlockMathSyntax();

  @override
  RegExp get pattern => RegExp(r'^\s*\$\$');

  @override
  md.Node parse(md.BlockParser parser) {
    final firstLine = parser.current.content.trim();
    final singleLineMatch = RegExp(r'^\$\$(.*?)\$\$\s*$').firstMatch(firstLine);
    if (singleLineMatch != null && singleLineMatch[1]!.trim().isNotEmpty) {
      parser.advance();
      return md.Element.text(
        _MarkdownMathTags.block,
        singleLineMatch[1]!.trim(),
      );
    }

    final firstLineRemainder = firstLine.substring(2).trim();
    final lines = <String>[
      if (firstLineRemainder.isNotEmpty) firstLineRemainder,
    ];
    parser.advance();

    while (!parser.isDone) {
      final line = parser.current.content;
      final trimmedLine = line.trim();
      if (trimmedLine == r'$$') {
        parser.advance();
        break;
      }

      if (trimmedLine.endsWith(r'$$')) {
        lines.add(line.substring(0, line.lastIndexOf(r'$$')).trimRight());
        parser.advance();
        break;
      }

      lines.add(line);
      parser.advance();
    }

    return md.Element.text(
      _MarkdownMathTags.block,
      lines.join('\n').trim(),
    );
  }
}

class MarkdownMathBuilder extends MarkdownElementBuilder {
  MarkdownMathBuilder({required this.displayMode});

  final bool displayMode;

  @override
  bool isBlockElement() => displayMode;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final theme = Theme.of(context);
    final tex = element.textContent.trim();
    final textStyle =
        (parentStyle ?? preferredStyle ?? theme.textTheme.bodyLarge)
            ?.copyWith(height: 1.35);
    final math = Math.tex(
      tex,
      mathStyle: displayMode ? MathStyle.display : MathStyle.text,
      textStyle: textStyle,
      onErrorFallback: (error) {
        return Text(
          tex,
          style: textStyle?.copyWith(color: theme.colorScheme.error),
        );
      },
    );

    if (!displayMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: math,
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: math,
      ),
    );
  }
}

class _MarkdownMathTags {
  const _MarkdownMathTags._();

  static const inline = 'evoly-math-inline';
  static const block = 'evoly-math-block';
}

class MarkdownMathSupport {
  const MarkdownMathSupport._();

  static List<md.InlineSyntax> inlineSyntaxes() {
    return [MarkdownInlineMathSyntax()];
  }

  static const blockSyntaxes = [MarkdownBlockMathSyntax()];

  static Map<String, MarkdownElementBuilder> builders() {
    return {
      _MarkdownMathTags.inline: MarkdownMathBuilder(displayMode: false),
      _MarkdownMathTags.block: MarkdownMathBuilder(displayMode: true),
    };
  }
}
