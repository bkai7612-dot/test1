import { useCallback, useEffect, useRef, useState, type DependencyList, type Dispatch, type SetStateAction } from 'react';

export interface QueryState<T> {
  data: T | undefined;
  loading: boolean;
  error: unknown;
  reload: () => Promise<void>;
  setData: Dispatch<SetStateAction<T | undefined>>;
}

/**
 * Runs an async loader whenever deps change. Responses from stale requests are
 * ignored so quickly switching property or filters never shows the wrong data.
 */
export function useQuery<T>(loader: () => Promise<T>, deps: DependencyList, enabled = true): QueryState<T> {
  const [data, setData] = useState<T | undefined>(undefined);
  const [loading, setLoading] = useState(enabled);
  const [error, setError] = useState<unknown>(null);
  const requestId = useRef(0);
  const loaderRef = useRef(loader);
  loaderRef.current = loader;

  const reload = useCallback(async () => {
    const id = ++requestId.current;
    setLoading(true);
    setError(null);
    try {
      const result = await loaderRef.current();
      if (id === requestId.current) setData(result);
    } catch (err) {
      if (id === requestId.current) setError(err);
    } finally {
      if (id === requestId.current) setLoading(false);
    }
  }, deps);

  useEffect(() => {
    if (enabled) void reload();
  }, [reload, enabled]);

  return { data, loading, error, reload, setData };
}
