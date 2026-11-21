// stop-addresses: short addresses for the stops on a day's route.
//
//   POST { day_id }   Authorization: the user (the route's owner or an admin)
//        200 { looked_up, remaining }
//
// Addresses are saved per ~100 m square, so a place is looked up once ever.
// A place with no address (a field, a river) is saved as '' so that Google
// is not asked again for it (L15).
// At most 10 lookups per call keeps the cost bounded; the app asks again
// when it opens the route next time.
import type { Backend } from '../_shared/backend.ts';
import { callerProfile } from '../_shared/caller.ts';
import { readBody, reply } from '../_shared/http.ts';
import type { Geocoder } from './geocode.ts';

export const MAX_LOOKUPS = 10;

export async function handler(
  req: Request,
  b: Backend,
  geocode: Geocoder | null,
): Promise<Response> {
  const body = await readBody(req);
  if (body instanceof Response) return body;
  const caller = await callerProfile(req, b);
  if (caller instanceof Response) return caller;

  const dayId = body.day_id;
  if (typeof dayId !== 'number' || !Number.isInteger(dayId) || dayId <= 0) {
    return reply(400, { error: 'validation_failed' });
  }
  const missing = await b.missingPlaces(dayId, caller.profile.id);
  if (missing === 'not_allowed') return reply(403, { error: 'not_allowed' });
  if (!geocode || missing.length === 0) {
    return reply(200, { looked_up: 0, remaining: missing.length });
  }

  const done: { cell_lat: number; cell_lng: number; address: string }[] = [];
  for (const m of missing.slice(0, MAX_LOOKUPS)) {
    try {
      const address = await geocode(m.lat, m.lng);
      done.push({ cell_lat: m.cell_lat, cell_lng: m.cell_lng, address: address ?? '' });
    } catch (e) {
      // Quota or network trouble: keep what we have, try again next time.
      console.error('geocode failed:', e instanceof Error ? e.message : 'unknown');
      break;
    }
  }
  if (done.length > 0) await b.savePlaces(dayId, done);
  return reply(200, {
    looked_up: done.filter((d) => d.address !== '').length,
    remaining: missing.length - done.length,
  });
}
