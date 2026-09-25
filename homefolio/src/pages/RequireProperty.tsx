import { Building2, Plus } from 'lucide-react';
import type { ReactNode } from 'react';
import { LinkButton } from '@/components/ui/Button';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useProperties } from '@/context/PropertyContext';

/** Renders children only once an active property exists. Keyed so switching property resets page state. */
export function RequireProperty({ children }: { children: ReactNode }) {
  const { active, loading, error, reload } = useProperties();
  if (loading) return <ListSkeleton />;
  if (error && !active) return <ErrorState error={error} onRetry={reload} />;
  if (!active)
    return (
      <EmptyState
        icon={Building2}
        title="Add your home first"
        description="Everything in Homefolio belongs to a property. Add your home to get started."
        action={
          <LinkButton to="/properties?new=1" icon={Plus}>
            Add property
          </LinkButton>
        }
      />
    );
  return <div key={active.id}>{children}</div>;
}
