import { Info, Pencil, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { DetailScaffold, useRecord } from '@/components/DetailScaffold';
import { DocumentsPanel } from '@/components/files/DocumentsPanel';
import { Button } from '@/components/ui/Button';
import { Section } from '@/components/ui/Card';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { DetailList, PageHeader } from '@/components/ui/Layout';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { deleteRow } from '@/lib/api';
import { contactLink } from '@/components/ui/contactLink';
import { formatDate, formatMoney, titleCase } from '@/lib/format';
import type { Utility } from '@/lib/types';
import { UtilityFormModal } from './Utilities';

export default function UtilityDetail() {
  const { id } = useParams();
  const property = useActiveProperty();
  const state = useRecord<Utility>('utilities', id);
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const navigate = useNavigate();
  const toast = useToast();

  return (
    <DetailScaffold state={state} backTo="/utilities" backLabel="Utilities" propertyId={property.id}>
      {(u) => (
        <>
          <PageHeader
            back={{ to: '/utilities', label: 'Utilities' }}
            title={titleCase(u.utility_type)}
            description={u.provider ?? undefined}
            actions={
              <>
                <Button variant="secondary" icon={Pencil} onClick={() => setEditing(true)}>
                  Edit
                </Button>
                <Button variant="secondary" icon={Trash2} onClick={() => setDeleting(true)}>
                  Delete
                </Button>
              </>
            }
          />
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
            <Section title="Details" icon={Info}>
              <DetailList
                items={[
                  { label: 'Provider', value: u.provider },
                  { label: 'Account / reference', value: u.account_number },
                  { label: 'Tariff / package', value: u.tariff },
                  { label: 'Monthly cost', value: formatMoney(u.monthly_cost) },
                  { label: 'Contract start', value: formatDate(u.contract_start) },
                  { label: 'Contract end', value: formatDate(u.contract_end) },
                  { label: 'Phone', value: contactLink(u.contact_phone, 'tel') },
                  { label: 'Email', value: contactLink(u.contact_email, 'email') },
                  { label: 'Website', value: contactLink(u.website, 'url'), full: true },
                  { label: 'Notes', value: u.notes, full: true },
                ]}
              />
            </Section>
            <DocumentsPanel
              propertyId={property.id}
              link={{ key: 'utility_id', id: u.id }}
              title="Bills & contracts"
              defaultCategory="Utilities"
              emptyText="Upload contracts, bills or welcome letters."
            />
          </div>
          <UtilityFormModal
            open={editing}
            onClose={() => setEditing(false)}
            propertyId={property.id}
            utility={u}
            onSaved={(s) => state.setData(s)}
          />
          <ConfirmDialog
            open={deleting}
            onClose={() => setDeleting(false)}
            title={`Delete ${titleCase(u.utility_type)}?`}
            message="These details will be deleted. Any documents are kept in Documents."
            onConfirm={async () => {
              await deleteRow('utilities', u.id);
              toast.success('Deleted');
              navigate('/utilities', { replace: true });
            }}
          />
        </>
      )}
    </DetailScaffold>
  );
}
