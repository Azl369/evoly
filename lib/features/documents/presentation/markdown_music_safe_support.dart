import 'package:evoly_markdown_music_preview/evoly_markdown_music_preview.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class SafeMarkdownMusicSupport {
  const SafeMarkdownMusicSupport._();

  static List<md.BlockSyntax> blockSyntaxes() {
    return [SafeMarkdownMusicBlockSyntax()];
  }

  static Map<String, MarkdownElementBuilder> builders() {
    return MarkdownMusicSupport.builders().map(
      (tag, builder) => MapEntry(tag, _BlockTextDrainBuilder(builder)),
    );
  }
}

enum _MusicBlockKind { chordpro, tab, abc }

class SafeMarkdownMusicBlockSyntax extends md.BlockSyntax {
  static final _openingPattern = RegExp(
    r'^\s*(`{3,}|~{3,})\s*([A-Za-z0-9_-]+)(?:\s+(.*))?\s*$',
  );
  static const _aliases = {
    'chord': _MusicBlockKind.chordpro,
    'chords': _MusicBlockKind.chordpro,
    'chordpro': _MusicBlockKind.chordpro,
    'tab': _MusicBlockKind.tab,
    'tabs': _MusicBlockKind.tab,
    'guitar-tab': _MusicBlockKind.tab,
    'abc': _MusicBlockKind.abc,
  };

  @override
  RegExp get pattern => _openingPattern;

  @override
  bool canParse(md.BlockParser parser) {
    final match = _openingPattern.firstMatch(parser.current.content);
    final language = match?[2]?.toLowerCase();
    return language != null && _aliases.containsKey(language);
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final match = _openingPattern.firstMatch(parser.current.content)!;
    final fence = match[1]!;
    final language = match[2]!.toLowerCase();
    final kind = _aliases[language]!;
    final lines = <String>[];

    parser.advance();
    while (!parser.isDone) {
      final line = parser.current.content;
      if (_isClosingFence(line, fence)) {
        parser.advance();
        break;
      }
      lines.add(line);
      parser.advance();
    }

    final source = lines.join('\n').trimRight();
    if (source.trim().isEmpty) {
      return md.Element('p', const []);
    }

    return md.Element.text(_tagFor(kind), source);
  }

  bool _isClosingFence(String line, String fence) {
    final trimmed = line.trim();
    if (trimmed.length < fence.length) {
      return false;
    }

    final char = fence.codeUnitAt(0);
    for (final unit in trimmed.codeUnits) {
      if (unit != char) {
        return false;
      }
    }
    return true;
  }

  String _tagFor(_MusicBlockKind kind) {
    return switch (kind) {
      _MusicBlockKind.chordpro => 'evoly-music-chordpro',
      _MusicBlockKind.tab => 'evoly-music-tab',
      _MusicBlockKind.abc => 'evoly-music-abc',
    };
  }
}

class _BlockTextDrainBuilder extends MarkdownElementBuilder {
  _BlockTextDrainBuilder(this.delegate);

  final MarkdownElementBuilder delegate;

  @override
  bool isBlockElement() => true;

  @override
  void visitElementBefore(md.Element element) {
    delegate.visitElementBefore(element);
  }

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    return delegate.visitText(text, preferredStyle) ?? const SizedBox.shrink();
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return delegate.visitElementAfterWithContext(
      context,
      element,
      preferredStyle,
      parentStyle,
    );
  }
}
