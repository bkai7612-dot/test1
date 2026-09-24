import { Building2, Check, Pencil, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { CustomFields } from '@/components/CustomFields';
import { PhotoGallery } from '@/components/files/PhotoGallery';
import { Tag } from '@/components/ui/Badges';
import { Button } from '@/components/ui/Button';
import { Section } from '@/components/ui/Card';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { DetailList, PageHeader } from '@/components/ui/Layout';
import { EmptyState, ListSkeleton } from '@/components/ui/States';
import { useProperties } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { deleteProperty } from '@/lib/api';
import { OWNERSHIP_STATUSES, PROPERTY_TYPES } from '@/lib/constants';
import { formatDate, labelFor, propertyAddress } from '@/lib/format';
import { PropertyFormModal } from './Properties';

export default function PropertyDetail() {
  const { id } = useParams();
  const { properties, active, setActive, loading, reload } = useProperties();
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const navigate = useNavigate();
  const toast = useToast();
  const property = properties.find((p) => p.id === id);

  if (loading) return <ListSkeleton />;
  if (!property)
    return (
      <EmptyState
        icon={Building2}
        title="Property not found"
        description="It may have been deleted."
        action={<Button onClick={() => navigate('/properties')}>Back to properties</Button>}
      />
    );

  const isActive = property.id === active?.id;

  return (
    <>
      <PageHeader
        back={{ to: '/properties', label: 'Properties' }}
        title={
          <span className="flex flex-wrap items-center gap-2">
            {property.name}
            {property.is_sample && <Tag>Sample</Tag>}
          </span>
        }
        description={propertyAddress(property) || undefined}
        actions={
          <>
            {!isActive && (
              <Button variant="secondary" icon={Check} onClick={() => setActive(property.id)}>
                Switch to this
              </Button>
            )}
            <Button variant="secondary" icon={Pencil} onClick={() => setEditing(true)}>
              Edit
            </Button>
          </>
        }
      />
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Section title="Property profile" icon={Building2}>
          <DetailList
            items={[
              { label: 'Address', value: propertyAddress(property), full: true },
              { label: 'Property type', value: labelFor(PROPERTY_TYPES, property.property_type) },
              { label: 'Ownership', value: labelFor(OWNERSHIP_STATUSES, property.ownership_status) },
              { label: 'Bedrooms', value: property.bedrooms?.toString() },
              { label: 'Bathrooms', value: property.bathrooms?.toString() },
              { label: 'Year built', value: property.year_built?.toString() },
              {
                label: property.ownership_status === 'renter' ? 'Rental start date' : 'Purchase / move-in date',
                value: formatDate(property.move_in_date),
              },
              { label: 'Notes', value: property.notes, full: true },
            ]}
          />
        </Section>
        <div className="space-y-4">
          <CustomFields propertyId={property.id} entityType="property" entityId={property.id} />
          <PhotoGallery propertyId={property.id} itemName={property.name} />
        </div>
      </div>
      <div className="mt-8 rounded-2xl border border-rose-200 p-4 sm:p-5 dark:border-rose-900/60">
        <h2 className="text-ink font-semibold">Delete property</h2>
        <p className="text-muted mt-1 text-sm">
          Permanently removes this property and everything in it — rooms, appliances, documents, photos and reminders.
        </p>
        <Button variant="danger" icon={Trash2} className="mt-4" onClick={() => setDeleting(true)}>
          Delete property
        </Button>
      </div>

      <PropertyFormModal open={editing} onClose={() => setEditing(false)} property={property} />
      <ConfirmDialog
        open={deleting}
        onClose={() => setDeleting(false)}
        title={`Delete ${property.name}?`}
        message="This permanently deletes the property and all of its information and files. This can't be undone."
        confirmText="DELETE"
        confirmLabel="Delete property"
        onConfirm={async () => {
          await deleteProperty(property.id);
          await reload();
          toast.success('Property deleted');
          navigate('/properties', { replace: true });
        }}
      />
    </>
  );
}
