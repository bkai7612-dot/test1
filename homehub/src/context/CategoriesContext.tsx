import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { DEFAULT_CATEGORIES } from '@/lib/constants';
import { unwrap } from '@/lib/errors';
import { supabase } from '@/lib/supabase';
import type { CategoryKind, CustomCategory } from '@/lib/types';
import { useAuth } from './AuthContext';

interface CategoriesState {
  custom: CustomCategory[];
  optionsFor: (kind: CategoryKind) => string[];
  add: (kind: CategoryKind, name: string) => Promise<string>;
  remove: (id: string) => Promise<void>;
}

const CategoriesContext = createContext<CategoriesState | null>(null);

/** Merges built-in categories with the user's own, loaded once per session. */
export function CategoriesProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [custom, setCustom] = useState<CustomCategory[]>([]);

  useEffect(() => {
    if (!user) {
      setCustom([]);
      return;
    }
    supabase
      .from('custom_categories')
      .select('*')
      .order('name')
      .then(({ data }) => setCustom((data as CustomCategory[] | null) ?? []));
  }, [user]);

  const optionsFor = useCallback(
    (kind: CategoryKind) => {
      const defaults = DEFAULT_CATEGORIES[kind];
      const extra = custom.filter((c) => c.kind === kind).map((c) => c.name);
      // Keep "Other" last so custom categories sit with the built-in ones.
      const withoutOther = defaults.filter((d) => d !== 'Other');
      const merged = [...withoutOther, ...extra.filter((e) => !defaults.includes(e))];
      return defaults.includes('Other') ? [...merged, 'Other'] : merged;
    },
    [custom],
  );

  const add = useCallback(
    async (kind: CategoryKind, name: string) => {
      const clean = name.trim().replace(/\s+/g, ' ');
      const existing = optionsFor(kind).find((o) => o.toLowerCase() === clean.toLowerCase());
      if (existing) return existing;
      const row = unwrap(
        await supabase.from('custom_categories').insert({ kind, name: clean }).select().single(),
      ) as CustomCategory;
      setCustom((c) => [...c, row].sort((a, b) => a.name.localeCompare(b.name)));
      return row.name;
    },
    [optionsFor],
  );

  const remove = useCallback(async (id: string) => {
    unwrap(await supabase.from('custom_categories').delete().eq('id', id));
    setCustom((c) => c.filter((x) => x.id !== id));
  }, []);

  const value = useMemo(() => ({ custom, optionsFor, add, remove }), [custom, optionsFor, add, remove]);
  return <CategoriesContext.Provider value={value}>{children}</CategoriesContext.Provider>;
}

export function useCategories(): CategoriesState {
  const ctx = useContext(CategoriesContext);
  if (!ctx) throw new Error('useCategories must be used inside CategoriesProvider');
  return ctx;
}
