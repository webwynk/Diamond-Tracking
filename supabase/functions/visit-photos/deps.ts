// What the visit-photos function needs from the outside world, as an interface.
//
// The routes are written against this, so the access rules can be tested with
// plain fakes and no Supabase or Cloudinary. `index.ts` supplies the real thing.

import type { CloudConfig } from './http.ts';

/** The columns of `public.visits` the photo routes read. */
export type VisitRow = {
  id: string;
  employee_id: string;
  photo_public_id: string | null;
  photo_removed_at: string | null;
  created_at: string;
};

export type DuePhoto = { id: string; photo_public_id: string };

export interface Deps {
  /** Null when a Cloudinary secret is missing. */
  cloud: CloudConfig | null;

  /** The token the nightly job sends; null or empty means purging is off. */
  purgeToken: string | null;

  now(): Date;
  fetch(input: string, init?: RequestInit): Promise<Response>;

  /** The signed-in user's id, or null when the token is not a valid session. */
  userId(auth: string): Promise<string | null>;

  /** Whether that session belongs to an active admin. */
  isAdmin(auth: string): Promise<boolean>;

  /**
   * One visit, under the CALLER's own rights: an employee gets only their own
   * visit, an admin any visit, and null when there is none they may see.
   */
  readVisit(auth: string, visitId: string): Promise<VisitRow | null>;

  /** Writes the photo onto the visit (server rights). False if it was not free. */
  attachPhoto(visitId: string, publicId: string, at: Date): Promise<boolean>;

  /** Photos older than [cutoff], oldest first, at most [limit]. */
  dueForPurge(cutoff: Date, limit: number): Promise<DuePhoto[]>;

  /** Records that a photo was deleted: no photo id, and when. */
  markPhotoRemoved(visitId: string, at: Date): Promise<void>;

  /** Writes one audit-log entry. */
  audit(action: string, details: Record<string, unknown>): Promise<void>;
}
