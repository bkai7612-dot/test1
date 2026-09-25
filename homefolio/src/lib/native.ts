/** Phone-only helpers (camera, share sheet). Each is a no-op fallback on web and Windows. */
import { isNative } from './platform';

/** Asks "Take photo or choose from library" and returns the picture as a File, or null if cancelled. */
export async function takeOrPickPhoto(): Promise<File | null> {
  const { Camera, CameraResultType, CameraSource } = await import('@capacitor/camera');
  try {
    const photo = await Camera.getPhoto({
      resultType: CameraResultType.Uri,
      source: CameraSource.Prompt,
      quality: 85,
      width: 1600,
      correctOrientation: true,
      promptLabelHeader: 'Add a photo',
      promptLabelPhoto: 'Choose from library',
      promptLabelPicture: 'Take a photo',
    });
    if (!photo.webPath) return null;
    const blob = await (await fetch(photo.webPath)).blob();
    const ext = photo.format || 'jpeg';
    return new File([blob], `photo-${Date.now()}.${ext}`, { type: blob.type || `image/${ext}` });
  } catch {
    // The user closed the picker.
    return null;
  }
}

/** Opens the phone's share sheet for a stored file (e.g. send a receipt by email or WhatsApp). */
export async function shareFile(url: string, fileName: string, title: string): Promise<void> {
  if (!isNative) return;
  const [{ Filesystem, Directory }, { Share }] = await Promise.all([import('@capacitor/filesystem'), import('@capacitor/share')]);
  const blob = await (await fetch(url)).blob();
  const base64 = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).split(',')[1] ?? '');
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
  const safe = fileName.replace(/[^\w.-]+/g, '-');
  const written = await Filesystem.writeFile({ path: safe, data: base64, directory: Directory.Cache });
  await Share.share({ title, files: [written.uri] });
}
