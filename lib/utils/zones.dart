/// Tanzania's 6 fleet zones — mirrors the `zone` enum validated by the
/// backend (`HospitalController`) and stored on every `Hospital` row.
const zoneLabels = {
  'coastal':   'Coastal Zone',
  'northern':  'Northern Zone',
  'lake':      'Lake Zone',
  'central':   'Central Zone',
  'shighland': 'Southern Highland',
  'southern':  'Southern Zone',
};

String zoneLabelFor(String? key) => zoneLabels[key] ?? '—';

String? zoneKeyForLabel(String? label) {
  if (label == null) return null;
  for (final e in zoneLabels.entries) {
    if (e.value == label) return e.key;
  }
  return null;
}
