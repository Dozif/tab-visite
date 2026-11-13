// Modèle du rapport de corrosion : saisies par point, inclusion, tri,
// totaux, numérotation. Module PUR (aucun accès disque, aucune API Electron) :
// utilisé par le processus principal (génération PDF) et par l'interface.

export const GRAVITES = ['critique', 'moyenne', 'mineure']

export const LIBELLE_GRAVITE = {
  critique: 'Critique', moyenne: 'Moyenne', mineure: 'Mineure'
}

export const PERIMETRE = {
  MKBAM: 'Motrices', MKBDR: 'Remorques', MKBAR: 'Remorques (autre série)'
}

const ORDRE_TYPE = ['MKBAM', 'MKBDR', 'MKBAR']

const rang = (liste, v) => {
  const i = liste.indexOf(v)
  return i < 0 ? liste.length : i
}

// 'dd/MM/yyyy' -> Date (pour comparer/trier).
function parseFr(d) {
  const [j, m, a] = String(d).split(' ')[0].split('/').map(Number)
  return new Date(a || 1970, (m || 1) - 1, j || 1)
}

const deux = (n) => String(n).padStart(2, '0')
const dateFr = (d) => `${deux(d.getDate())}/${deux(d.getMonth() + 1)}/${d.getFullYear()}`

const memePoint = (p, visiteId, plan, zone) =>
  p.visiteId === visiteId && p.plan === plan && p.zone === zone

export function findPoint(lib, visiteId, plan, zone) {
  return (lib.points ?? []).find((p) => memePoint(p, visiteId, plan, zone)) ?? null
}

/** Crée ou met à jour un point ; renvoie une NOUVELLE bibliothèque. */
export function setPoint(lib, { visiteId, plan, zone, ...patch }) {
  const points = [...(lib.points ?? [])]
  const i = points.findIndex((p) => memePoint(p, visiteId, plan, zone))
  const avant = i >= 0 ? points[i] : {
    visiteId, plan, zone, gravite: null, tempsChaud: null, tempsPeinture: null,
    commentaire: '', inclusion: 'auto', marque: null
  }
  const apres = { ...avant, ...patch }
  if (i >= 0) points[i] = apres
  else points.push(apres)
  return { ...lib, points }
}

const heure = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : null)

/** Main-d'œuvre d'un point (chaudronnerie + peinture), ou null si rien saisi. */
export function tempsTotal(point) {
  const c = heure(point?.tempsChaud)
  const p = heure(point?.tempsPeinture)
  return c === null && p === null ? null : (c ?? 0) + (p ?? 0)
}

/** Le point part-il dans le rapport ? */
export function estInclus(point) {
  if (!point) return false
  if (point.inclusion === 'oui') return true
  if (point.inclusion === 'non') return false
  return !!point.gravite && tempsTotal(point) !== null
}

/** Points (zones photographiées) d'une visite, dans l'ordre d'import. */
export function pointsDeVisite(lib, visiteId) {
  const parCle = new Map()
  // Ordre d'import ; les bibliothèques antérieures (sans « ordre ») gardent
  // l'ordre du tableau, qui est aussi celui de l'import.
  const photos = lib.photos
    .map((ph, i) => ({ ph, rang: ph.ordre ?? i }))
    .filter(({ ph }) => ph.visiteId === visiteId)
    .sort((a, b) => a.rang - b.rang)
  for (const { ph, rang } of photos) {
    const cle = `${ph.plan}\u0000${ph.zone}`
    if (!parCle.has(cle)) {
      parCle.set(cle, {
        plan: ph.plan, zone: ph.zone, ordre: rang, photos: [],
        point: findPoint(lib, visiteId, ph.plan, ph.zone)
      })
    }
    parCle.get(cle).photos.push(ph)
  }
  return [...parCle.values()]
}

export function resumeVisite(lib, visiteId) {
  const inclus = pointsDeVisite(lib, visiteId).filter((p) => estInclus(p.point))
  return {
    nbPoints: inclus.length,
    heures: inclus.reduce((s, p) => s + (tempsTotal(p.point) ?? 0), 0)
  }
}

/** Visites cochées par défaut : celles de la date la plus récente de la rame. */
export function visitesParDefaut(lib, rame) {
  const visites = lib.visites.filter((v) => v.rame === rame)
  if (visites.length === 0) return []
  const max = Math.max(...visites.map((v) => parseFr(v.dateVisite).getTime()))
  return visites.filter((v) => parseFr(v.dateVisite).getTime() === max).map((v) => v.id)
}

/** Prochain numéro de rapport ; renvoie aussi les réglages mis à jour. */
export function numeroRapport(reglages, rame, date) {
  const prefixe = `RC-${rame}-${date.getFullYear()}${deux(date.getMonth() + 1)}${deux(date.getDate())}`
  const compteurs = { ...(reglages?.dernierNumero ?? {}) }
  const n = (compteurs[prefixe] ?? 0) + 1
  compteurs[prefixe] = n
  return {
    numero: n === 1 ? prefixe : `${prefixe}-${n}`,
    reglages: { ...(reglages ?? {}), dernierNumero: compteurs }
  }
}

const uniques = (xs) => [...new Set(xs)]

/**
 * @param sechageH séchage final (h) après la dernière intervention, saisi au
 *   niveau du rapport ; jamais additionné à la main-d'œuvre.
 */
export function buildRapport(lib, { rame, visiteIds, redacteur, dateEdition, numero, sechageH }) {
  const visites = lib.visites
    .filter((v) => v.rame === rame && visiteIds.includes(v.id))
    .sort((a, b) => rang(ORDRE_TYPE, a.type) - rang(ORDRE_TYPE, b.type) ||
      parseFr(a.dateVisite) - parseFr(b.dateVisite))

  const brut = []
  visites.forEach((v, iv) => {
    for (const p of pointsDeVisite(lib, v.id)) {
      if (!estInclus(p.point)) continue
      brut.push({ v, iv, p })
    }
  })
  if (brut.length === 0) throw new Error('Aucun point à inclure')

  brut.sort((a, b) =>
    rang(GRAVITES, a.p.point.gravite) - rang(GRAVITES, b.p.point.gravite) ||
    a.iv - b.iv ||
    a.p.ordre - b.p.ordre ||
    a.p.zone.localeCompare(b.p.zone, 'fr'))

  const legendes = lib.legendes ?? {}
  const points = brut.map(({ v, p }, i) => {
    const m = p.point.marque
    return {
      n: i + 1,
      zone: p.zone,
      plan: p.plan,
      typeVisite: v.type,
      gravite: p.point.gravite ?? null,
      tempsChaud: heure(p.point.tempsChaud),
      tempsPeinture: heure(p.point.tempsPeinture),
      tempsH: tempsTotal(p.point), // main-d'œuvre du point
      commentaire: p.point.commentaire ?? '',
      photos: p.photos.map((ph) => ({
        chemin: ph.chemin, datePrise: ph.datePrise, legende: legendes[ph.id] ?? ''
      })),
      // Rond placé à la main (éventuellement sur un autre dessin), sinon
      // rond automatique sur la zone du point.
      dessin: m?.dessin ?? p.photos.find((ph) => ph.dessin)?.dessin ?? null,
      marque: m ? { cx: m.cx, cy: m.cy, rx: m.rx, ry: m.ry } : null,
      zoneRect: p.photos.find((ph) => ph.zoneRect)?.zoneRect ?? null
    }
  })

  const somme = (pts, champ) => pts.reduce((s, p) => s + (p[champ] ?? 0), 0)
  const heures = (pts) => somme(pts, 'tempsH')
  const parGravite = {}
  for (const g of GRAVITES) {
    const pts = points.filter((p) => p.gravite === g)
    parGravite[g] = { n: pts.length, h: heures(pts) }
  }
  // Points inclus à la main sans gravité : comptés à part pour que la
  // répartition couvre bien tous les points.
  const sansGravite = points.filter((p) => !GRAVITES.includes(p.gravite))
  const nonEvaluee = { n: sansGravite.length, h: heures(sansGravite) }

  return {
    numero,
    rame,
    niveaux: uniques(visites.map((v) => v.niveau)).join(' / '),
    datesVisite: uniques(visites.map((v) => v.dateVisite)).join(', '),
    redacteur: redacteur ?? '',
    editeLe: dateFr(dateEdition),
    visites: visites.map((v) => {
      const pts = points.filter((p) => brut[p.n - 1].v.id === v.id)
      return {
        type: v.type, perimetre: PERIMETRE[v.type] ?? v.type, niveau: v.niveau,
        dateVisite: v.dateVisite, nbPoints: pts.length, heures: heures(pts)
      }
    }),
    synthese: {
      nbPoints: points.length,
      heures: heures(points), // main-d'œuvre totale
      chaud: somme(points, 'tempsChaud'),
      peinture: somme(points, 'tempsPeinture'),
      sechage: heure(sechageH),
      parGravite,
      nonEvaluee
    },
    points
  }
}

/** 1.5 -> '1,5 h' ; null -> '—'. */
export function formatHeures(h) {
  if (h === null || h === undefined || !Number.isFinite(h)) return '—'
  return `${h.toFixed(1).replace('.', ',')} h`
}
