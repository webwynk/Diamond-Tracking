// Turns a position into a short address with Google's Geocoding API.

export type Geocoder = (lat: number, lng: number) => Promise<string | null>;

interface Component {
  long_name: string;
  short_name: string;
  types: string[];
}

interface Result {
  formatted_address?: string;
  address_components?: Component[];
  types?: string[];
}

/**
 * "Krishi Kendra Rd, Barasat": the place or road, then the area. Falls back to
 * the first two parts of the full address. Plus codes are skipped.
 */
export function compactAddress(results: Result[]): string | null {
  const usable = results.filter((r) => !(r.types ?? []).includes('plus_code'));
  if (usable.length === 0) return null;
  const pick = (types: string[]): string | null => {
    for (const r of usable) {
      for (const t of types) {
        const c = (r.address_components ?? []).find((c) => c.types.includes(t));
        if (c && !/^[A-Z0-9]{4}\+[A-Z0-9]{2,}/.test(c.long_name)) return c.long_name;
      }
    }
    return null;
  };
  const place = pick(['point_of_interest', 'establishment', 'premise', 'route']);
  const area = pick([
    'sublocality_level_1',
    'sublocality',
    'locality',
    'administrative_area_level_3',
    'administrative_area_level_2',
  ]);
  const parts = [place, area].filter((p): p is string => !!p);
  const unique = parts.filter((p, i) => parts.indexOf(p) === i);
  if (unique.length > 0) return unique.join(', ').slice(0, 200);
  const formatted = usable[0].formatted_address ?? '';
  const short = formatted.split(',').slice(0, 2).map((p) => p.trim()).filter(Boolean).join(', ');
  return short ? short.slice(0, 200) : null;
}

export function googleGeocoder(key: string, fetcher: typeof fetch = fetch): Geocoder {
  return async (lat, lng) => {
    const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
    url.searchParams.set('latlng', `${lat},${lng}`);
    url.searchParams.set('language', 'en');
    url.searchParams.set('region', 'in');
    url.searchParams.set('key', key);
    const res = await fetcher(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) throw new Error(`geocoding http ${res.status}`);
    const body = await res.json() as { status: string; results?: Result[] };
    if (body.status === 'ZERO_RESULTS') return null;
    if (body.status !== 'OK') throw new Error(`geocoding ${body.status}`);
    return compactAddress(body.results ?? []);
  };
}
