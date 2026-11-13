import 'package:flutter_test/flutter_test.dart';
import 'package:tab_visite/services/mail_export.dart';

void main() {
  test('mailto avec destinataires, objet et corps encodés', () {
    final uri = mailtoExport(
      destinataires: ['franck.dozieres@sncf.fr', 'denis.martel@sncf.fr'],
      objet: 'Export visites corrosion – 13/11/2026',
      corps: 'Pièce jointe : a b.zip',
    );
    final s = uri.toString();
    expect(s, startsWith('mailto:franck.dozieres@sncf.fr,denis.martel@sncf.fr?'));
    expect(s, contains('subject=Export%20visites%20corrosion%20%E2%80%93%2013%2F11%2F2026'));
    expect(s, contains('body=Pi%C3%A8ce%20jointe%20%3A%20a%20b.zip'));
    expect(s, isNot(contains('+')));
  });

  test('mailto sans destinataire', () {
    expect(mailtoExport(destinataires: [], objet: 'O', corps: 'C').toString(),
        'mailto:?subject=O&body=C');
  });
}
