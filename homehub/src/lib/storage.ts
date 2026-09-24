import { DOCUMENT_TYPES, IMAGE_TYPES, MAX_UPLOAD_BYTES } from './constants';
import { FriendlyError } from './errors';
import { STORAGE_BUCKET, supabase } from './supabase';

export type UploadKind = 'image' | 'document';

const EXTENSION_TYPES: Record<string, string> = {
  pdf: 'application/pdf',
  txt: 'text/plain',
  doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  gif: 'image/gif',
  heic: 'image/heic',
  heif: 'image/heif',
};

/** Some browsers leave file.type empty (e.g. HEIC on desktop), so fall back to the extension. */
export function mimeTypeOf(file: File): string {
  if (file.type) return file.type;
  const ext = file.name.split('.').pop()?.toLowerCase() ?? '';
  return EXTENSION_TYPES[ext] ?? 'application/octet-stream';
}

export function validateFile(file: File, kind: UploadKind): void {
  const type = mimeTypeOf(file);
  const allowed = kind === 'image' ? IMAGE_TYPES : DOCUMENT_TYPES;
  if (!allowed.includes(type)) {
    throw new FriendlyError(
      kind === 'image'
        ? `"${file.name}" isn't a supported image. Please use JPG, PNG, WEBP, GIF or HEIC.`
        : `"${file.name}" isn't a supported file type. Please use PDF, an image, Word or text files.`,
    );
  }
  if (file.size > MAX_UPLOAD_BYTES) {
    throw new FriendlyError(`"${file.name}" is too large. The maximum size is 20 MB.`);
  }
  if (file.size === 0) throw new FriendlyError(`"${file.name}" is empty.`);
}

const MAX_IMAGE_EDGE = 1600;

/** Downscales large photos in the browser before upload to save space and bandwidth. */
export async function optimiseImage(file: File): Promise<Blob> {
  const type = mimeTypeOf(file);
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(type)) return file;
  try {
    const bitmap = await createImageBitmap(file);
    const scale = Math.min(1, MAX_IMAGE_EDGE / Math.max(bitmap.width, bitmap.height));
    if (scale === 1 && file.size < 1.5 * 1024 * 1024) {
      bitmap.close();
      return file;
    }
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(bitmap.width * scale);
    canvas.height = Math.round(bitmap.height * scale);
    canvas.getContext('2d')?.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    bitmap.close();
    const outType = type === 'image/png' ? 'image/png' : 'image/jpeg';
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, outType, 0.85));
    return blob && blob.size < file.size ? blob : file;
  } catch {
    return file;
  }
}

function safeName(name: string): string {
  const cleaned = name
    .normalize('NFKD')
    .replace(/[^\w.-]+/g, '-')
    .replace(/-+/g, '-')
    .slice(-80);
  return cleaned || 'file';
}

export interface UploadedFile {
  path: string;
  name: string;
  mimeType: string;
  size: number;
}

/**
 * Uploads into the private bucket under "<user>/<property>/<folder>/".
 * Storage policies only allow a user to touch paths beginning with their own id.
 */
export async function uploadFile(
  userId: string,
  propertyId: string,
  folder: string,
  file: File,
  kind: UploadKind,
): Promise<UploadedFile> {
  validateFile(file, kind);
  const mimeType = mimeTypeOf(file);
  const body = mimeType.startsWith('image/') ? await optimiseImage(file) : file;
  const path = `${userId}/${propertyId}/${folder}/${crypto.randomUUID()}-${safeName(file.name)}`;
  const { error } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(path, body, { contentType: body.type || mimeType, upsert: false, cacheControl: '3600' });
  if (error) throw error;
  return { path, name: file.name, mimeType: body.type || mimeType, size: body.size };
}

const SIGNED_URL_TTL = 60 * 60;
const urlCache = new Map<string, { url: string; expires: number }>();

function cached(path: string): string | null {
  const hit = urlCache.get(path);
  return hit && hit.expires > Date.now() ? hit.url : null;
}

/** Short-lived signed URLs, batched and cached, since the bucket is private. */
export async function getSignedUrls(paths: string[]): Promise<Record<string, string>> {
  const result: Record<string, string> = {};
  const missing: string[] = [];
  for (const p of paths) {
    const url = cached(p);
    if (url) result[p] = url;
    else missing.push(p);
  }
  if (missing.length) {
    const { data, error } = await supabase.storage.from(STORAGE_BUCKET).createSignedUrls(missing, SIGNED_URL_TTL);
    if (error) throw error;
    for (const item of data ?? []) {
      if (item.path && item.signedUrl) {
        result[item.path] = item.signedUrl;
        urlCache.set(item.path, { url: item.signedUrl, expires: Date.now() + (SIGNED_URL_TTL - 120) * 1000 });
      }
    }
  }
  return result;
}

export async function getDownloadUrl(path: string, fileName: string): Promise<string> {
  const { data, error } = await supabase.storage.from(STORAGE_BUCKET).createSignedUrl(path, 120, { download: fileName });
  if (error) throw error;
  return data.signedUrl;
}

export async function removeFiles(paths: (string | null | undefined)[]): Promise<void> {
  const clean = paths.filter((p): p is string => Boolean(p));
  for (let i = 0; i < clean.length; i += 100) {
    const batch = clean.slice(i, i + 100);
    const { error } = await supabase.storage.from(STORAGE_BUCKET).remove(batch);
    if (error) throw error;
    batch.forEach((p) => urlCache.delete(p));
  }
}

export function isImage(mime: string | null | undefined): boolean {
  return Boolean(mime?.startsWith('image/'));
}

export function isPdf(mime: string | null | undefined): boolean {
  return mime === 'application/pdf';
}
