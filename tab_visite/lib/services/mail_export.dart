/// Lien `mailto:` ouvrant un nouveau mail dans l'appli mail de la tablette
/// (Outlook, Gmail…). Un site web ne peut pas y joindre de fichier : le ZIP
/// est ajouté à la main depuis « Téléchargements ».
///
/// Encodage en `%20` (et non `+`) : certaines applis mail affichent les `+`.
Uri mailtoExport({
  required List<String> destinataires,
  required String objet,
  required String corps,
}) {
  final query = {'subject': objet, 'body': corps}
      .entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return Uri.parse('mailto:${destinataires.join(',')}?$query');
}
