import { SearchX } from 'lucide-react';
import type { ReactNode } from 'react';
import { useQuery } from '@/hooks/useQuery';
import { fetchById, type Table } from '@/lib/api';
import { LinkButton } from './ui/Button';
import { EmptyState, ErrorState, ListSkeleton } from './ui/States';

/** Loads one record by id for a detail page. */
export function useRecord<T>(table: Table, id: string | undefined) {
  return useQuery(() => fetchById<T>(table, id ?? ''), [table, id], Boolean(id));
}

interface DetailScaffoldProps<T> {
  state: { data: T | null | undefined; loading: boolean; error: unknown; reload: () => void };
  backTo: string;
  backLabel: string;
  /** Guard against records from another property (e.g. after switching). */
  propertyId?: string;
  children: (record: T) => ReactNode;
}

/** Handles loading, error and not-found states so detail pages only render the happy path. */
export function DetailScaffold<T extends { property_id?: string }>({
  state,
  backTo,
  backLabel,
  propertyId,
  children,
}: DetailScaffoldProps<T>) {
  const { data, loading, error, reload } = state;
  if (loading && !data) return <ListSkeleton rows={3} />;
  if (error) return <ErrorState error={error} onRetry={reload} />;
  if (!data || (propertyId && data.property_id && data.property_id !== propertyId))
    return (
      <EmptyState
        icon={SearchX}
        title="Not found"
        description="This may have been deleted, or it belongs to a different property."
        action={
          <LinkButton to={backTo} variant="secondary">
            Back to {backLabel.toLowerCase()}
          </LinkButton>
        }
      />
    );
  return <>{children(data)}</>;
}
