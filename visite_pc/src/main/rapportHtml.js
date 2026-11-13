// Rendu HTML du rapport de corrosion (gabarit = maquette validée,
// docs/superpowers/specs/2026-11-13-rapport-maquette/). Imprimé en PDF par
// rapportPdf.js via webContents.printToPDF.
import { formatHeures, LIBELLE_GRAVITE } from '../shared/rapport.js'

export function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

const texte = (s) => escapeHtml(s).replace(/\r?\n/g, '<br>')

const CLASSE = { critique: 'crit', moyenne: 'moy', mineure: 'min' }
const classe = (g) => CLASSE[g] ?? 'nev'
const libelle = (g) => LIBELLE_GRAVITE[g] ?? 'Non évaluée'
const badge = (g) => `<span class="badge ${classe(g)}">${libelle(g)}</span>`

const n4 = (v) => String(Number(v.toFixed(4)))

function extrait(commentaire, max = 60) {
  const t = String(commentaire ?? '').replace(/\s+/g, ' ').trim()
  return t.length > max ? t.slice(0, max) + '…' : t
}

const CSS = `
  @page { size: A4; margin: 14mm 14mm 18mm 14mm; }
  :root {
    --bleu: #1f3a5f; --gris: #5b6573; --trait: #d5dae1; --fond: #f3f5f8;
    --crit: #c62828; --moy: #e67e00; --min: #2e7d32; --nev: #7a8594;
  }
  * { box-sizing: border-box; }
  body { font-family: "Segoe UI", Roboto, Arial, sans-serif; color: #1c2430; font-size: 10.5pt; margin: 0; }
  h1, h2, h3 { margin: 0; }
  .entete { display: flex; justify-content: space-between; align-items: flex-end;
            border-bottom: 3px solid var(--bleu); padding-bottom: 8px; }
  .entete h1 { font-size: 20pt; color: var(--bleu); letter-spacing: .3px; }
  .entete .sous { color: var(--gris); font-size: 10pt; margin-top: 2px; }
  .entete .rame { text-align: right; }
  .entete .rame b { display: block; font-size: 22pt; color: var(--bleu); line-height: 1; }
  .entete .rame span { color: var(--gris); font-size: 9pt; }
  .infos { display: grid; grid-template-columns: repeat(4, 1fr); margin: 12px 0 14px;
           border: 1px solid var(--trait); border-radius: 6px; overflow: hidden; }
  .infos div { padding: 7px 10px; border-right: 1px solid var(--trait); }
  .infos div:last-child { border-right: 0; }
  .infos label { display: block; font-size: 7.5pt; text-transform: uppercase; color: var(--gris); letter-spacing: .5px; }
  .infos span { font-weight: 600; }
  h2 { font-size: 12pt; color: var(--bleu); margin: 16px 0 6px; padding-bottom: 3px; border-bottom: 1px solid var(--trait); }
  table { width: 100%; border-collapse: collapse; font-size: 9.5pt; }
  thead { display: table-header-group; }
  tr { break-inside: avoid; }
  th { background: var(--bleu); color: #fff; text-align: left; font-weight: 600; padding: 5px 7px; font-size: 8.5pt; }
  td { padding: 5px 7px; border-bottom: 1px solid var(--trait); vertical-align: top; }
  tr:nth-child(even) td { background: var(--fond); }
  td.pt { white-space: nowrap; }
  td.num, th.num { text-align: right; white-space: nowrap; }
  tfoot td { font-weight: 700; background: #e8edf3 !important; border-top: 2px solid var(--bleu); }
  .synthese { display: grid; grid-template-columns: 1fr 1fr 2fr; gap: 10px; margin-top: 4px; }
  .carte { border: 1px solid var(--trait); border-radius: 6px; padding: 9px 12px; }
  .carte label { font-size: 7.5pt; text-transform: uppercase; color: var(--gris); letter-spacing: .5px; }
  .carte .gros { font-size: 22pt; font-weight: 700; color: var(--bleu); line-height: 1.1; }
  .repart { display: flex; gap: 8px; margin-top: 6px; flex-wrap: wrap; }
  .badge { display: inline-block; padding: 2px 9px; border-radius: 10px; color: #fff; font-weight: 700;
           font-size: 8.5pt; white-space: nowrap; }
  .crit { background: var(--crit); } .moy { background: var(--moy); }
  .min { background: var(--min); } .nev { background: var(--nev); }
  .saut { break-before: page; }
  .point { break-inside: avoid; border: 1px solid var(--trait); border-radius: 7px; margin-bottom: 9px; overflow: hidden; }
  .point-tete { display: flex; align-items: center; gap: 10px; padding: 7px 10px; background: var(--fond);
                border-bottom: 1px solid var(--trait); }
  .point-tete .n { width: 24px; height: 24px; border-radius: 50%; background: var(--bleu); color: #fff;
                   display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 9.5pt; flex: none; }
  .point-tete .titre { flex: 1; }
  .point-tete .titre b { font-size: 12pt; }
  .point-tete .titre span { color: var(--gris); font-size: 9pt; margin-left: 6px; }
  .point-tete .temps { font-weight: 700; font-size: 11pt; color: var(--bleu); margin-left: 8px; white-space: nowrap; }
  .point-corps { padding: 5px 10px 8px; }
  .loc { text-align: center; border: 1px solid var(--trait); border-radius: 4px; background: #fff; padding: 2px; }
  .loc .cadre { position: relative; display: inline-block; vertical-align: top; }
  .loc img { height: 24mm; width: auto; max-width: 100%; display: block; }
  .loc svg { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; }
  .legende { font-size: 7.5pt; color: var(--gris); text-transform: uppercase; letter-spacing: .5px; margin: 4px 0 2px; }
  .photos { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .photos figure { margin: 0; break-inside: avoid; }
  .photos img { width: 100%; height: 47mm; object-fit: cover; border-radius: 4px; display: block; }
  .photos figcaption { font-size: 8pt; color: var(--gris); margin-top: 2px; }
  .constat { border-left: 4px solid var(--bleu); background: var(--fond); padding: 6px 10px; border-radius: 0 4px 4px 0; line-height: 1.4; }
  .bord-crit { border-left-color: var(--crit); } .bord-moy { border-left-color: var(--moy); }
  .bord-min { border-left-color: var(--min); } .bord-nev { border-left-color: var(--nev); }
  .vide { color: var(--gris); font-style: italic; }
  .signature { margin-top: 18px; display: flex; justify-content: flex-end; break-inside: avoid; }
  .signature div { width: 70mm; border-top: 1px solid var(--gris); padding-top: 4px; font-size: 9pt; color: var(--gris); }
`

const PLURIEL = { critique: 'critique', moyenne: 'moyen', mineure: 'mineur' }

function localisation(p, fileUrl) {
  if (!p.dessin) return ''
  let ellipse = ''
  if (p.zoneRect) {
    const { x, y, l, h } = p.zoneRect
    ellipse = `<svg viewBox="0 0 1 1" preserveAspectRatio="none">` +
      `<ellipse cx="${n4(x + l / 2)}" cy="${n4(y + h / 2)}" rx="${n4(l / 2 + 0.012)}" ry="${n4(h / 2 + 0.024)}" ` +
      `fill="none" stroke="#dc0000" stroke-width="3" vector-effect="non-scaling-stroke"/></svg>`
  }
  return `<div class="legende">Localisation</div>
    <div class="loc"><span class="cadre"><img src="${escapeHtml(fileUrl(p.dessin))}">${ellipse}</span></div>`
}

function fiche(p, fileUrl) {
  const photos = p.photos.length === 0 ? '' : `<div class="legende">Photos</div>
    <div class="photos">${p.photos.map((ph) => `
      <figure><img src="${escapeHtml(fileUrl(ph.chemin))}">
        <figcaption>${escapeHtml(ph.datePrise)}${ph.legende ? ' — ' + escapeHtml(ph.legende) : ''}</figcaption></figure>`).join('')}
    </div>`
  const constat = p.commentaire
    ? texte(p.commentaire)
    : '<span class="vide">Aucun commentaire.</span>'
  return `
<div class="point">
  <div class="point-tete"><div class="n">${p.n}</div>
    <div class="titre"><b>${escapeHtml(p.zone)}</b><span>${escapeHtml(p.plan)} · Visite ${escapeHtml(p.typeVisite)}</span></div>
    ${badge(p.gravite)}<span class="temps">${formatHeures(p.tempsH)}</span></div>
  <div class="point-corps">
    ${localisation(p, fileUrl)}
    ${photos}
    <div class="legende">Constat et travaux à prévoir</div>
    <div class="constat bord-${classe(p.gravite)}">${constat}</div>
  </div>
</div>`
}

/**
 * HTML complet du rapport.
 * @param rapport résultat de buildRapport (src/shared/rapport.js)
 * @param fileUrl (cheminRelatifBibliotheque) => URL file:// de l'image
 */
export function renderRapportHtml(rapport, fileUrl) {
  const r = rapport
  const s = r.synthese
  const repart = Object.entries(s.parGravite)
    .filter(([, v]) => v.n > 0)
    .map(([g, v]) => `<span class="badge ${classe(g)}">${v.n} ${PLURIEL[g]}${v.n > 1 ? 's' : ''} · ${formatHeures(v.h)}</span>`)
    .join('')
  const plusieursDates = r.datesVisite.includes(',')

  return `<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<title>Rapport ${escapeHtml(r.numero)} — Rame ${escapeHtml(r.rame)}</title>
<style>${CSS}</style></head>
<body>
<div class="entete">
  <div><h1>Rapport de visite corrosion</h1><div class="sous">Constats et travaux à prévoir</div></div>
  <div class="rame"><span>Rame</span><b>${escapeHtml(r.rame)}</b><span>Niveau ${escapeHtml(r.niveaux)}</span></div>
</div>

<div class="infos">
  <div><label>N° de rapport</label><span>${escapeHtml(r.numero)}</span></div>
  <div><label>${plusieursDates ? 'Dates de visite' : 'Date de visite'}</label><span>${escapeHtml(r.datesVisite)}</span></div>
  <div><label>Rédigé par</label><span>${escapeHtml(r.redacteur) || '—'}</span></div>
  <div><label>Édité le</label><span>${escapeHtml(r.editeLe)}</span></div>
</div>

<h2>Visites incluses</h2>
<table>
  <thead><tr><th>Type</th><th>Périmètre</th><th>Niveau</th><th>Date</th><th class="num">Points</th><th class="num">Temps</th></tr></thead>
  <tbody>${r.visites.map((v) => `
    <tr><td><b>${escapeHtml(v.type)}</b></td><td>${escapeHtml(v.perimetre)}</td><td>${escapeHtml(v.niveau)}</td>
      <td>${escapeHtml(v.dateVisite)}</td><td class="num">${v.nbPoints}</td><td class="num">${formatHeures(v.heures)}</td></tr>`).join('')}
  </tbody>
</table>

<h2>Synthèse</h2>
<div class="synthese">
  <div class="carte"><label>Points à traiter</label><div class="gros">${s.nbPoints}</div></div>
  <div class="carte"><label>Temps total estimé</label><div class="gros">${formatHeures(s.heures)}</div></div>
  <div class="carte"><label>Répartition par gravité</label><div class="repart">${repart}</div></div>
</div>

<h2>Récapitulatif des points</h2>
<table>
  <thead><tr><th>N°</th><th>Point</th><th>Voiture / dessin</th><th>Gravité</th><th class="num">Temps</th><th>Constat</th></tr></thead>
  <tbody>${r.points.map((p) => `
    <tr><td>${p.n}</td><td class="pt"><b>${escapeHtml(p.zone)}</b></td><td>${escapeHtml(p.plan)}</td>
      <td>${badge(p.gravite)}</td><td class="num">${formatHeures(p.tempsH)}</td><td>${escapeHtml(extrait(p.commentaire))}</td></tr>`).join('')}
  </tbody>
  <tfoot><tr><td colspan="4">Total — ${s.nbPoints} point${s.nbPoints > 1 ? 's' : ''}</td><td class="num">${formatHeures(s.heures)}</td><td></td></tr></tfoot>
</table>

<h2 class="saut">Détail des points</h2>
${r.points.map((p) => fiche(p, fileUrl)).join('')}

<div class="signature"><div>Rédigé par ${escapeHtml(r.redacteur) || '—'}, le ${escapeHtml(r.editeLe)}</div></div>
</body></html>`
}

/** Pied de page (gabarit printToPDF : pageNumber / totalPages). */
export function footerTemplate(rapport) {
  return '<div style="font-family:Segoe UI,Arial,sans-serif;font-size:8px;color:#5b6573;' +
    'width:100%;padding:0 14mm;display:flex;justify-content:space-between">' +
    `<span>Rapport ${escapeHtml(rapport.numero)} · Rame ${escapeHtml(rapport.rame)}</span>` +
    '<span>Page <span class="pageNumber"></span> / <span class="totalPages"></span></span></div>'
}
