import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

/**
 * Tracks which record is open in a form modal: null (closed), 'new', or a row.
 * Opens automatically for "?new=1" links (used by dashboard quick actions).
 */
export function useEditor<T>() {
  const [editing, setEditing] = useState<T | 'new' | null>(null);
  const [params, setParams] = useSearchParams();

  useEffect(() => {
    if (params.get('new') === '1') {
      setEditing('new');
      params.delete('new');
      setParams(params, { replace: true });
    }
  }, [params, setParams]);

  return {
    editing,
    isOpen: editing !== null,
    row: editing && editing !== 'new' ? editing : null,
    openNew: () => setEditing('new'),
    openEdit: (row: T) => setEditing(row),
    close: () => setEditing(null),
  };
}
