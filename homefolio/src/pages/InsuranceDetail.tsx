import { Info, Pencil, Phone, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { DetailScaffold, useRecord } from '@/components/DetailScaffold';
import { DocumentsPanel } from '@/components/files/DocumentsPanel';
import { StatusBadge } from '@/components/ui/Badges';
import { Button } from '@/components/ui/Button';
import { Section } from '@/components/ui/Card';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { contactLink } from '@/components/ui/contactLink';
import { DetailList, PageHeader } from '@/components/ui/Layout';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { deleteRow } from '@/lib/api';
import { formatDate, formatMoney, telHref } from '@/lib/format';
import type { InsurancePolicy } from '@/lib/types';
import { InsuranceFormModal, policyTitle, renewalBadge } from './Insurance';

export default function InsuranceDetail() {
  const { id } = useParams();
  const property = useActiveProperty();
  const state = useRecord<InsurancePolicy>('insurance_policies', id);
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const navigate = useNavigate();
  const toast = useToast();

  return (
    <DetailScaffold state={state} backTo="/insurance" backLabel="Insurance" propertyId={property.id}>
      {(p) => {
        const badge = renewalBadge(p);
        return (
          <>
            <PageHeader
              back={{ to: '/insurance', label: 'Insurance' }}
              title={policyTitle(p)}
              description={
                <span className="flex flex-wrap items-center gap-2">
                  {p.provider}
                  {badge && <StatusBadge status={badge.status} label={badge.label} />}
                </span>
              }
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
            {p.emergency_phone && (
              <a
                href={telHref(p.emergency_phone)}
                className="border-line bg-surface hover:border-brand-300 mb-4 flex items-center gap-3 rounded-2xl border p-4"
              >
                <span className="bg-brand-600 flex size-11 items-center justify-center rounded-xl text-white">
                  <Phone className="size-5" aria-hidden />
                </span>
                <span>
                  <span className="text-muted block text-sm">Claims / emergency line</span>
                  <span className="text-ink block text-lg font-semibold">{p.emergency_phone}</span>
                </span>
              </a>
            )}
            <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
              <Section title="Policy details" icon={Info}>
                <DetailList
                  items={[
                    { label: 'Provider', value: p.provider },
                    { label: 'Policy number', value: p.policy_number },
                    { label: 'Start date', value: formatDate(p.start_date) },
                    { label: 'Renewal date', value: formatDate(p.renewal_date) },
                    {
                      label: 'Premium',
                      value:
                        p.premium !== null
                          ? `${formatMoney(p.premium)} ${p.premium_frequency === 'monthly' ? 'per month' : 'per year'}`
                          : null,
                    },
                    { label: 'Customer services', value: contactLink(p.contact_phone, 'tel') },
                    { label: 'Email', value: contactLink(p.contact_email, 'email') },
                    { label: 'Notes', value: p.notes, full: true },
                  ]}
                />
              </Section>
              <DocumentsPanel
                propertyId={property.id}
                link={{ key: 'insurance_policy_id', id: p.id }}
                title="Policy documents"
                defaultCategory="Insurance"
                emptyText="Upload your policy schedule and terms."
              />
            </div>
            <InsuranceFormModal
              open={editing}
              onClose={() => setEditing(false)}
              propertyId={property.id}
              policy={p}
              onSaved={(s) => state.setData(s)}
            />
            <ConfirmDialog
              open={deleting}
              onClose={() => setDeleting(false)}
              title="Delete this policy?"
              message="The policy details will be deleted. Policy documents are kept in Documents."
              onConfirm={async () => {
                await deleteRow('insurance_policies', p.id);
                toast.success('Policy deleted');
                navigate('/insurance', { replace: true });
              }}
            />
          </>
        );
      }}
    </DetailScaffold>
  );
}
