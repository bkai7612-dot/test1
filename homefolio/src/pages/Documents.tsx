import { FileText, Upload } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { DocumentFormModal, DocumentViewModal } from '@/components/files/DocumentModals';
import { DocumentRow } from '@/components/files/DocumentsPanel';
import { Button } from '@/components/ui/Button';
import { Chips, PageHeader, SearchInput } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useCategories } from '@/context/CategoriesContext';
import { useActiveProperty } from '@/context/PropertyContext';
import { useDebounced } from '@/hooks/useData';
import { useEditor } from '@/hooks/useEditor';
import { useQuery } from '@/hooks/useQuery';
import { PAGE_SIZE } from '@/lib/constants';
import { unwrap } from '@/lib/errors';
import { supabase } from '@/lib/supabase';
import type { HomeDocument } from '@/lib/types';

type Row = HomeDocument & {
  appliance: { name: string } | null;
  inventory: { name: string } | null;
  room: { name: string } | null;
  task: { title: string } | null;
  insurance: { provider: string | null; policy_type: string } | null;
  utility: { provider: string | null; utility_type: string } | null;
  council_tax: { council: string | null } | null;
};

const SELECT = `*,
  appliance:appliances(name),
  inventory:inventory_items(name),
  room:rooms(name),
  task:maintenance_tasks(title),
  insurance:insurance_policies(provider, policy_type),
  utility:utilities(provider, utility_type),
  council_tax:council_tax(council)`;

function attachedTo(d: Row): string | null {
  return (
    d.appliance?.name ??
    d.inventory?.name ??
    d.room?.name ??
    d.task?.title ??
    (d.insurance ? (d.insurance.provider ?? 'Insurance policy') : null) ??
    (d.utility ? [d.utility.utility_type, d.utility.provider].filter(Boolean).join(' – ') : null) ??
    (d.council_tax ? 'Council tax' : null)
  );
}

/** Drops characters that have meaning inside a PostgREST or() filter or an ILIKE pattern. */
function escapeSearch(q: string): string {
  return q.replace(/[%_\\,()"*:]/g, ' ').trim();
}

export default function Documents() {
  const property = useActiveProperty();
  const { optionsFor } = useCategories();
  const editor = useEditor<HomeDocument>();
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('all');
  const [limit, setLimit] = useState(PAGE_SIZE);
  const [viewing, setViewing] = useState<Row | null>(null);
  const q = useDebounced(search.trim());

  useEffect(() => setLimit(PAGE_SIZE), [q, category]);

  // Deep link from search: /documents?open=<id>
  const [params, setParams] = useSearchParams();
  const openId = params.get('open');
  useEffect(() => {
    if (!openId) return;
    supabase
      .from('documents')
      .select(SELECT)
      .eq('id', openId)
      .maybeSingle()
      .then(({ data: doc }) => {
        if (doc) setViewing(doc as unknown as Row);
      });
    params.delete('open');
    setParams(params, { replace: true });
  }, [openId, params, setParams]);

  const { data, loading, error, reload } = useQuery(async () => {
    let query = supabase.from('documents').select(SELECT, { count: 'exact' }).eq('property_id', property.id);
    if (category !== 'all') query = query.eq('category', category);
    if (q) {
      const p = `%${escapeSearch(q)}%`;
      query = query.or(`name.ilike.${p},category.ilike.${p},file_name.ilike.${p},notes.ilike.${p},extracted_text.ilike.${p}`);
    }
    const res = await query.order('created_at', { ascending: false }).range(0, limit - 1);
    return { rows: unwrap(res) as unknown as Row[], total: res.count ?? 0 };
  }, [property.id, category, q, limit]);

  const rows = data?.rows ?? [];
  const filtering = Boolean(q) || category !== 'all';

  const uploadButton = (
    <Button icon={Upload} onClick={editor.openNew}>
      Upload
    </Button>
  );

  return (
    <>
      <PageHeader
        title="Documents"
        description="Receipts, manuals, certificates and policies — all in one place."
        actions={uploadButton}
      />
      <div className="mb-4 space-y-3">
        <SearchInput value={search} onChange={setSearch} placeholder="Search documents" />
        <Chips
          label="Filter by category"
          value={category}
          onChange={setCategory}
          options={[{ value: 'all', label: 'All' }, ...optionsFor('document').map((c) => ({ value: c, label: c }))]}
        />
      </div>
      {loading && !data ? (
        <ListSkeleton />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !rows.length ? (
        filtering ? (
          <EmptyState compact icon={FileText} title="No matching documents" description="Try a different search or category." />
        ) : (
          <EmptyState
            icon={FileText}
            title="No documents yet"
            description="Upload receipts, manuals, insurance policies and certificates so they're always to hand."
            action={uploadButton}
          />
        )
      ) : (
        <>
          <ul className="grid grid-cols-1 gap-2 lg:grid-cols-2">
            {rows.map((d) => (
              <li key={d.id}>
                <DocumentRow doc={d} onOpen={() => setViewing(d)} attachedTo={attachedTo(d)} />
              </li>
            ))}
          </ul>
          <p className="text-muted mt-4 text-center text-sm">
            Showing {rows.length} of {data?.total}
          </p>
          {rows.length < (data?.total ?? 0) && (
            <Button variant="secondary" className="mt-3 w-full" loading={loading} onClick={() => setLimit((l) => l + PAGE_SIZE)}>
              Load more
            </Button>
          )}
        </>
      )}

      <DocumentFormModal
        open={editor.isOpen}
        onClose={editor.close}
        propertyId={property.id}
        document={editor.row}
        onSaved={reload}
      />
      <DocumentViewModal
        document={viewing}
        attachedTo={viewing ? attachedTo(viewing) : null}
        onClose={() => setViewing(null)}
        onEdit={(d) => {
          setViewing(null);
          editor.openEdit(d);
        }}
        onDeleted={reload}
      />
    </>
  );
}
