import { MapPinOff } from 'lucide-react';
import { LinkButton } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/States';

export default function NotFound() {
  return (
    <EmptyState
      icon={MapPinOff}
      title="Page not found"
      description="The page you're looking for doesn't exist."
      action={<LinkButton to="/">Go to dashboard</LinkButton>}
    />
  );
}
