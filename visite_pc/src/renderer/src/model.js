// Convertit 'dd/MM/yyyy' en Date (pour comparer/trier).
function parseFr(d) {
  const [j, m, a] = String(d).split('/').map(Number)
  return new Date(a, (m || 1) - 1, j || 1)
}

export function rames(lib) {
  const parRame = new Map()
  for (const v of lib.visites) {
    const e = parRame.get(v.rame) ?? { rame: v.rame, nbVisites: 0, derniereDate: v.dateVisite }
    e.nbVisites += 1
    if (parseFr(v.dateVisite) > parseFr(e.derniereDate)) e.derniereDate = v.dateVisite
    parRame.set(v.rame, e)
  }
  return [...parRame.values()].sort((a, b) => a.rame - b.rame)
}

export function visitesForRame(lib, rame) {
  const nbPhotos = (visiteId) => lib.photos.filter((p) => p.visiteId === visiteId).length
  return lib.visites
    .filter((v) => v.rame === rame)
    .map((v) => ({ ...v, nbPhotos: nbPhotos(v.id) }))
    .sort((a, b) => parseFr(b.dateVisite) - parseFr(a.dateVisite))
}

export function photosForVisite(lib, visiteId, filtre = {}) {
  let photos = lib.photos.filter((p) => p.visiteId === visiteId)
  if (filtre.traitee !== undefined) photos = photos.filter((p) => p.traitee === filtre.traitee)

  const parPlan = new Map()
  for (const p of photos) {
    if (!parPlan.has(p.plan)) parPlan.set(p.plan, new Map())
    const zones = parPlan.get(p.plan)
    if (!zones.has(p.zone)) zones.set(p.zone, [])
    zones.get(p.zone).push(p)
  }
  return [...parPlan.entries()].map(([plan, zones]) => ({
    plan,
    zones: [...zones.entries()].map(([zone, ps]) => ({ zone, photos: ps }))
  }))
}
