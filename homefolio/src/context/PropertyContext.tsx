import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { unwrap } from '@/lib/errors';
import { supabase } from '@/lib/supabase';
import type { Property } from '@/lib/types';
import { useAuth } from './AuthContext';

interface PropertyState {
  properties: Property[];
  active: Property | null;
  loading: boolean;
  error: unknown;
  setActive: (id: string) => void;
  reload: () => Promise<Property[]>;
}

const PropertyContext = createContext<PropertyState | null>(null);
const KEY = 'homefolio-active-property';

function readStored(userId: string): string | null {
  try {
    return localStorage.getItem(`${KEY}:${userId}`);
  } catch {
    return null;
  }
}

export function PropertyProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const userId = user?.id;
  const [properties, setProperties] = useState<Property[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);

  const reload = useCallback(async () => {
    if (!userId) return [];
    try {
      const rows = unwrap(await supabase.from('properties').select('*').order('is_sample').order('created_at')) as Property[];
      setProperties(rows);
      setError(null);
      return rows;
    } catch (err) {
      setError(err);
      return [];
    } finally {
      setLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    if (!userId) {
      setProperties([]);
      setActiveId(null);
      return;
    }
    setLoading(true);
    setActiveId(readStored(userId));
    void reload();
  }, [userId, reload]);

  const setActive = useCallback(
    (id: string) => {
      setActiveId(id);
      try {
        if (userId) localStorage.setItem(`${KEY}:${userId}`, id);
      } catch {
        // ignore
      }
    },
    [userId],
  );

  const active = useMemo(() => properties.find((p) => p.id === activeId) ?? properties[0] ?? null, [properties, activeId]);

  const value = useMemo<PropertyState>(
    () => ({ properties, active, loading, error, setActive, reload }),
    [properties, active, loading, error, setActive, reload],
  );

  return <PropertyContext.Provider value={value}>{children}</PropertyContext.Provider>;
}

export function useProperties(): PropertyState {
  const ctx = useContext(PropertyContext);
  if (!ctx) throw new Error('useProperties must be used inside PropertyProvider');
  return ctx;
}

/** For pages rendered inside RequireProperty, where an active property is guaranteed. */
export function useActiveProperty(): Property {
  const { active } = useProperties();
  if (!active) throw new Error('useActiveProperty called without an active property');
  return active;
}
