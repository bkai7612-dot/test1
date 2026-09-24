import { unwrap } from './errors';
import { removeFiles, uploadFile } from './storage';
import { supabase } from '@/lib/supabase';
import type { HomeDocument, LinkKey, Photo } from './types';

export type Table =
  | 'properties'
  | 'rooms'
  | 'appliances'
  | 'inventory_items'
  | 'warranties'
  | 'maintenance_tasks'
  | 'utilities'
  | 'council_tax'
  | 'insurance_policies'
  | 'meter_readings'
  | 'household_members'
  | 'emergency_contacts'
  | 'documents'
  | 'photos'
  | 'custom_fields'
  | 'custom_categories'
  | 'profiles';

export type Values = Record<string, unknown>;

export async function insertRow<T>(table: Table, values: Values): Promise<T> {
  return unwrap(await supabase.from(table).insert(values).select().single()) as T;
}

export async function updateRow<T>(table: Table, id: string, values: Values): Promise<T> {
  return unwrap(await supabase.from(table).update(values).eq('id', id).select().single()) as T;
}

export async function deleteRow(table: Table, id: string): Promise<void> {
  unwrap(await supabase.from(table).delete().eq('id', id));
}

export async function fetchById<T>(table: Table, id: string): Promise<T | null> {
  return unwrap(await supabase.from(table).select('*').eq('id', id).maybeSingle()) as T | null;
}

/** Storage folder used for each kind of attachment. */
const FOLDERS: Record<LinkKey | 'property', string> = {
  property: 'property',
  room_id: 'rooms',
  appliance_id: 'appliances',
  inventory_item_id: 'inventory',
  maintenance_task_id: 'maintenance',
  insurance_policy_id: 'insurance',
  utility_id: 'utilities',
  council_tax_id: 'council-tax',
  meter_reading_id: 'meter-readings',
};

export interface Link {
  key: LinkKey;
  id: string;
}

export async function addPhoto(userId: string, propertyId: string, file: File, link?: Link): Promise<Photo> {
  const uploaded = await uploadFile(userId, propertyId, `photos/${FOLDERS[link?.key ?? 'property']}`, file, 'image');
  try {
    return await insertRow<Photo>('photos', {
      property_id: propertyId,
      file_path: uploaded.path,
      ...(link ? { [link.key]: link.id } : {}),
    });
  } catch (err) {
    await removeFiles([uploaded.path]).catch(() => undefined);
    throw err;
  }
}

export async function removePhoto(photo: Photo): Promise<void> {
  await deleteRow('photos', photo.id);
  await removeFiles([photo.file_path]).catch(() => undefined);
}

export interface NewDocument {
  name: string;
  category: string;
  notes?: string | null;
  link?: Link | null;
}

export async function addDocument(userId: string, propertyId: string, file: File, meta: NewDocument): Promise<HomeDocument> {
  const folder = `documents/${FOLDERS[meta.link?.key ?? 'property']}`;
  const uploaded = await uploadFile(userId, propertyId, folder, file, 'document');
  try {
    return await insertRow<HomeDocument>('documents', {
      property_id: propertyId,
      name: meta.name,
      category: meta.category,
      notes: meta.notes ?? null,
      file_path: uploaded.path,
      file_name: uploaded.name,
      mime_type: uploaded.mimeType,
      size_bytes: uploaded.size,
      ...(meta.link ? { [meta.link.key]: meta.link.id } : {}),
    });
  } catch (err) {
    await removeFiles([uploaded.path]).catch(() => undefined);
    throw err;
  }
}

export async function removeDocument(doc: HomeDocument): Promise<void> {
  await deleteRow('documents', doc.id);
  await removeFiles([doc.file_path]).catch(() => undefined);
}

/**
 * Deletes a record together with its photos' stored files. Photo rows cascade
 * in the database, but files in storage must be removed explicitly.
 * Documents are kept (they stay in the central Documents section).
 */
export async function deleteWithPhotos(table: Table, id: string, linkKey: LinkKey): Promise<void> {
  const photos = unwrap(await supabase.from('photos').select('file_path').eq(linkKey, id)) as { file_path: string }[];
  await deleteRow(table, id);
  await removeFiles(photos.map((p) => p.file_path)).catch(() => undefined);
}

async function filePaths(filter: { column: 'property_id' | 'user_id'; value: string }): Promise<string[]> {
  const [docs, photos] = await Promise.all([
    supabase.from('documents').select('file_path').eq(filter.column, filter.value).not('file_path', 'is', null),
    supabase.from('photos').select('file_path').eq(filter.column, filter.value),
  ]);
  return [
    ...(unwrap(docs) as { file_path: string }[]).map((d) => d.file_path),
    ...(unwrap(photos) as { file_path: string }[]).map((p) => p.file_path),
  ];
}

/** Removes a property, everything in it (via cascade) and all its stored files. */
export async function deleteProperty(propertyId: string): Promise<void> {
  const paths = await filePaths({ column: 'property_id', value: propertyId });
  await removeFiles(paths);
  await deleteRow('properties', propertyId);
}

/** Permanently deletes the signed-in user's files and account. */
export async function deleteAccount(userId: string): Promise<void> {
  const paths = await filePaths({ column: 'user_id', value: userId });
  await removeFiles(paths);
  unwrap(await supabase.rpc('delete_my_account'));
}
