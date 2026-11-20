import { assertEquals } from '@std/assert';
import { FakeBackend, post } from '../_shared/fake_backend_test_support.ts';
import { compactAddress, googleGeocoder } from './geocode.ts';
import { handler, MAX_LOOKUPS } from './handler.ts';

function setup() {
  const b = new FakeBackend();
  const emp = b.addUser({ user_code: 'DA-001' }, 'emp');
  b.addUser({ user_code: 'DA-002' }, 'other');
  b.addUser({ user_code: 'boss', role: 'admin' }, 'admin');
  b.dayOwners.set(7, emp);
  b.missing = [{ cell_lat: 22700, cell_lng: 88400, lat: 22.7, lng: 88.4 }];
  return b;
}

Deno.test('looks up and saves the missing addresses', async () => {
  const b = setup();
  const res = await handler(
    post({ day_id: 7 }, 'emp'),
    b,
    () => Promise.resolve('Main Rd, Barasat'),
  );
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { looked_up: 1, remaining: 0 });
  assertEquals(b.saved, [{ cell_lat: 22700, cell_lng: 88400, address: 'Main Rd, Barasat' }]);
});

Deno.test('admins may ask, other employees may not', async () => {
  const b = setup();
  const geo = () => Promise.resolve('X');
  assertEquals((await handler(post({ day_id: 7 }, 'admin'), b, geo)).status, 200);
  assertEquals((await handler(post({ day_id: 7 }, 'other'), b, geo)).status, 403);
  assertEquals((await handler(post({ day_id: 7 }), b, geo)).status, 401);
  assertEquals((await handler(post({ day_id: 'x' }, 'emp'), b, geo)).status, 400);
});

Deno.test('at most 10 lookups a call, and stops on an error', async () => {
  const b = setup();
  b.missing = Array.from({ length: 15 }, (_, i) => ({
    cell_lat: i,
    cell_lng: i,
    lat: i / 1000,
    lng: i / 1000,
  }));
  let calls = 0;
  const res = await handler(post({ day_id: 7 }, 'emp'), b, () => {
    calls++;
    return Promise.resolve('Place');
  });
  assertEquals(calls, MAX_LOOKUPS);
  assertEquals((await res.json()).remaining, 5);

  let n = 0;
  const failing = await handler(post({ day_id: 7 }, 'emp'), b, () => {
    if (++n === 3) return Promise.reject(new Error('OVER_QUERY_LIMIT'));
    return Promise.resolve('Place');
  });
  assertEquals((await failing.json()).looked_up, 2);
});

Deno.test('without a key nothing is looked up', async () => {
  const b = setup();
  const res = await handler(post({ day_id: 7 }, 'emp'), b, null);
  assertEquals(await res.json(), { looked_up: 0, remaining: 1 });
});

Deno.test('compact address: place and area', () => {
  assertEquals(
    compactAddress([
      { types: ['plus_code'], address_components: [] },
      {
        formatted_address: '12, Krishi Kendra Rd, Barasat, West Bengal 700124, India',
        address_components: [
          { long_name: '12', short_name: '12', types: ['street_number'] },
          { long_name: 'Krishi Kendra Road', short_name: 'Krishi Kendra Rd', types: ['route'] },
          { long_name: 'Barasat', short_name: 'Barasat', types: ['locality', 'political'] },
        ],
      },
    ]),
    'Krishi Kendra Road, Barasat',
  );
  assertEquals(
    compactAddress([{ formatted_address: 'Village Rd, Habra, India', address_components: [] }]),
    'Village Rd, Habra',
  );
  assertEquals(compactAddress([{ types: ['plus_code'] }]), null);
});

Deno.test('google geocoder sends the key and reads the reply', async () => {
  let asked = '';
  const fake = ((url: URL) => {
    asked = url.toString();
    return Promise.resolve(
      new Response(JSON.stringify({
        status: 'OK',
        results: [{
          address_components: [{ long_name: 'Barasat', short_name: 'B', types: ['locality'] }],
        }],
      })),
    );
  }) as unknown as typeof fetch;
  assertEquals(await googleGeocoder('k1', fake)(22.7, 88.4), 'Barasat');
  assertEquals(asked.includes('latlng=22.7%2C88.4') && asked.includes('key=k1'), true);
});
