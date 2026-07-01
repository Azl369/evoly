import 'package:evoly/features/documents/presentation/markdown_math_support.dart';
import 'package:evoly_markdown_music_preview/evoly_markdown_music_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  test('Evoly markdown preview supports math and music blocks together', () {
    final document = md.Document(
      blockSyntaxes: [
        ...MarkdownMathSupport.blockSyntaxes,
        ...MarkdownMusicSupport.blockSyntaxes(),
      ],
      inlineSyntaxes: MarkdownMathSupport.inlineSyntaxes(),
    );

    final nodes = document.parseLines([
      '# Practice note',
      '',
      r'Inline math $x^2 + y^2 = z^2$.',
      '',
      r'$$',
      r'E = mc^2',
      r'$$',
      '',
      '```chordpro',
      '{title: Simple}',
      '[C]Hello [G]Evoly',
      '```',
      '',
      '```tab',
      'e|---0-1-3-|',
      'B|---------|',
      'G|---------|',
      'D|---------|',
      'A|---------|',
      'E|---------|',
      '```',
      '',
      '```abc',
      'X:1',
      'T:C Major Scale',
      'K:C',
      'C D E F |',
      '```',
    ]);

    final elements = nodes.whereType<md.Element>().toList();

    expect(
      elements.any((element) => element.tag == 'evoly-math-block'),
      isTrue,
    );
    expect(
      elements.any((element) => element.tag == 'evoly-music-chordpro'),
      isTrue,
    );
    expect(
      elements.any((element) => element.tag == 'evoly-music-tab'),
      isTrue,
    );
    expect(
      elements.any((element) => element.tag == 'evoly-music-abc'),
      isTrue,
    );
  });

  test('music templates expose fenced markdown snippets for editor insertion',
      () {
    expect(MarkdownMusicTemplates.all, hasLength(3));

    for (final template in MarkdownMusicTemplates.all) {
      expect(template.fencedSource, startsWith('```'));
      expect(template.fencedSource, endsWith('```'));
      expect(template.fencedSource, contains(template.fenceLanguage));
      expect(template.label.trim(), isNotEmpty);
      expect(template.description.trim(), isNotEmpty);
    }
  });
}
