import * as XLSX from 'xlsx'

export function parseDataXlsx(buffer) {
  const wb = XLSX.read(buffer, { type: 'buffer' })
  const ws = wb.Sheets['Photos'] ?? wb.Sheets[wb.SheetNames[0]]
  const raw = XLSX.utils.sheet_to_json(ws, { defval: '' })
  return raw.map((r) => ({
    rame: Number(r['Rame']),
    type: String(r['Type']),
    niveau: String(r['Niveau']),
    dateVisite: String(r['Date visite']),
    plan: String(r['Plan']),
    zone: String(r['Zone']),
    datePrise: String(r['Date prise']),
    traitee: String(r['Traitée']).toLowerCase() === 'oui',
    cheminPhoto: String(r['Chemin photo']),
    visiteId: String(r['Visite ID']),
    photoId: String(r['Photo ID'])
  }))
}
