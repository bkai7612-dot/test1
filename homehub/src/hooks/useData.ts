import { useEffect, useState } from 'react';
import { unwrap } from '@/lib/errors';
import { getSignedUrls } from '@/lib/storage';
import { supabase } from '@/lib/supabase';
import type { Room } from '@/lib/types';
import { useQuery } from './useQuery';

/** Rooms of a property, used by room pickers and room names on cards. */
export function useRooms(propertyId: string) {
  return useQuery(
    async () => unwrap(await supabase.from('rooms').select('*').eq('property_id', propertyId).order('name')) as Room[],
    [propertyId],
  );
}

/** Resolves signed URLs for private files; returns a path → url map. */
export function useSignedUrls(paths: (string | null | undefined)[]): Record<string, string> {
  const [urls, setUrls] = useState<Record<string, string>>({});
  const key = paths.filter(Boolean).join('|');

  useEffect(() => {
    const list = key ? key.split('|') : [];
    if (!list.length) return;
    let cancelled = false;
    getSignedUrls(list)
      .then((map) => {
        if (!cancelled) setUrls((prev) => ({ ...prev, ...map }));
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, [key]);

  return urls;
}

export function useDebounced<T>(value: T, delay = 250): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(value), delay);
    return () => window.clearTimeout(t);
  }, [value, delay]);
  return debounced;
}
