/** Example home for the prototype. Mirrors supabase/migrations/*_sample_home.sql. */

export type Row = Record<string, unknown>;
export type Store = Record<string, Row[]> & { __files: [string, string][] };

export const DEMO_USER = { id: '11111111-1111-4111-8111-111111111111', email: 'kai@example.com', name: 'Kai' };

/** Screenshots for the app stores add #plus to hide sponsored cards. */
export function demoPlus(): boolean {
  try {
    return window.location.hash.includes('plus') || localStorage.getItem('homefolio-demo-plus') === '1';
  } catch {
    return false;
  }
}

/** Foreign-key column that points at each table (used for embeds and cascades). */
export const FK: Record<string, string> = {
  properties: 'property_id',
  rooms: 'room_id',
  appliances: 'appliance_id',
  inventory_items: 'inventory_item_id',
  maintenance_tasks: 'maintenance_task_id',
  insurance_policies: 'insurance_policy_id',
  utilities: 'utility_id',
  council_tax: 'council_tax_id',
  meter_readings: 'meter_reading_id',
};

const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const days = (n: number) => {
  const d = new Date();
  d.setDate(d.getDate() + n);
  return iso(d);
};
const months = (n: number, base = new Date()) => {
  const d = new Date(base);
  d.setMonth(d.getMonth() + n);
  return iso(d);
};
const years = (n: number, from: string) => {
  const d = new Date(`${from}T00:00:00`);
  d.setFullYear(d.getFullYear() + n);
  return iso(d);
};

/** Builds a small, valid one-page PDF so document previews have something real to show. */
function makePdf(title: string, lines: string[]): Blob {
  const esc = (s: string) => s.replace(/[\\()]/g, (c) => `\\${c}`);
  const text = [
    `BT /F1 20 Tf 50 760 Td (${esc(title)}) Tj ET`,
    ...lines.map((l, i) => `BT /F1 12 Tf 50 ${720 - i * 22} Td (${esc(l)}) Tj ET`),
  ].join('\n');
  const objs = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    `<< /Length ${text.length} >>\nstream\n${text}\nendstream`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let pdf = '%PDF-1.4\n';
  const offsets: number[] = [];
  objs.forEach((o, i) => {
    offsets.push(pdf.length);
    pdf += `${i + 1} 0 obj\n${o}\nendobj\n`;
  });
  const xref = pdf.length;
  pdf += `xref\n0 ${objs.length + 1}\n0000000000 65535 f \n`;
  offsets.forEach((o) => (pdf += `${String(o).padStart(10, '0')} 00000 n \n`));
  pdf += `trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  return new Blob([pdf], { type: 'application/pdf' });
}

export function createSeed({ sample = false }: { sample?: boolean } = {}): Store {
  const uid = DEMO_USER.id;
  const now = new Date().toISOString();
  const id = () => crypto.randomUUID();
  const s: Store = { __files: [] } as unknown as Store;
  const add = (t: string, row: Row): string => {
    const r = { id: id(), user_id: uid, created_at: now, updated_at: now, ...row };
    (s[t] ??= []).push(r);
    return r.id as string;
  };

  if (!sample) {
    add('profiles', {
      id: uid,
      full_name: DEMO_USER.name,
      theme: 'system',
      reminder_window_days: 120,
      remind_maintenance: true,
      remind_warranties: true,
      remind_insurance: true,
      remind_contracts: true,
      // The prototype shows the free plan (with a sponsored card) unless
      // screenshots ask for Plus; the admin page is open so it can be explored.
      plan: demoPlus() ? 'plus' : 'free',
      plan_expires_at: null,
      plan_source: demoPlus() ? 'promo' : null,
      is_admin: true,
      tour_completed_at: null,
    });
    const today = new Date();
    const inDays = (n: number) => iso(new Date(today.getFullYear(), today.getMonth(), today.getDate() + n));
    add('ad_campaigns', {
      advertiser: 'Example Heating Co.',
      placement: 'dashboard',
      headline: 'Boiler service from £69',
      body: 'Gas Safe registered engineers across the county. Book online in two minutes.',
      cta_label: 'Book a service',
      url: 'https://example.com/boiler-service',
      logo_url: null,
      starts_on: inDays(-10),
      ends_on: inDays(50),
      weight: 1,
      active: true,
      price_per_month: 240,
      notes: 'Sample campaign for the prototype.',
    });
    add('ad_campaigns', {
      advertiser: 'Example Appliance Repairs',
      placement: 'maintenance',
      headline: 'Washing machine playing up?',
      body: 'Same-week repairs for all major brands, with a 12-month guarantee.',
      cta_label: 'Get a quote',
      url: 'https://example.com/repairs',
      logo_url: null,
      starts_on: inDays(-3),
      ends_on: inDays(27),
      weight: 1,
      active: true,
      price_per_month: 100,
      notes: null,
    });
    for (const [kind, name] of [
      ['appliance', 'Coffee machine'],
      ['document', 'Guarantees'],
    ] as const)
      add('custom_categories', { kind, name });
  }

  const p = add('properties', {
    name: sample ? 'Sample Flat' : 'My Home',
    address_line1: sample ? 'Flat 3, 15 Example Road' : '24 Example Street',
    address_line2: null,
    town: 'Sampletown',
    postcode: sample ? 'AB2 3EF' : 'AB1 2CD',
    property_type: sample ? 'flat' : 'house',
    ownership_status: sample ? 'renter' : 'owner',
    bedrooms: sample ? 1 : 3,
    bathrooms: 1,
    year_built: sample ? 2012 : 1998,
    move_in_date: months(-48),
    notes: sample
      ? 'Sample data to explore Homefolio. Remove it any time from Settings.'
      : 'Loft access is in the main bedroom cupboard.',
    is_sample: sample,
  });
  const P = { property_id: p };

  const room = (name: string, notes: string | null = null) => add('rooms', { ...P, name, room_type: name, notes });
  const kitchen = room('Kitchen');
  const living = room('Living Room');
  const bedroom = room('Bedroom', 'Paint: Dulux "Egyptian Cotton", matt.');
  room('Bathroom');
  const hallway = room('Hallway', 'Stopcock is under the stairs, behind the hoover.');
  if (!sample) room('Garden');

  const item = (t: 'appliances' | 'inventory_items', values: Row) =>
    add(t, {
      ...P,
      room_id: null,
      category: null,
      brand: null,
      model: null,
      serial_number: null,
      purchase_date: null,
      purchase_price: null,
      retailer: null,
      notes: null,
      ...(t === 'appliances' ? { condition: 'Good' } : { current_value: null }),
      ...values,
    });
  const warranty = (key: 'appliance_id' | 'inventory_item_id', itemId: string, provider: string, start: string, yrs: number) =>
    add('warranties', {
      ...P,
      appliance_id: null,
      inventory_item_id: null,
      [key]: itemId,
      provider,
      start_date: start,
      expiry_date: years(yrs, start),
      notes: null,
    });

  const washerBought = months(-14);
  const washer = item('appliances', {
    room_id: kitchen,
    name: 'Samsung Washing Machine',
    category: 'Washing machine',
    brand: 'Samsung',
    model: 'WW90T534DAW',
    serial_number: 'SN-WM-4471902',
    purchase_date: washerBought,
    purchase_price: 449,
    retailer: 'Currys',
  });
  warranty('appliance_id', washer, 'Samsung', washerBought, 5);
  const dishBought = months(-23);
  const dishwasher = item('appliances', {
    room_id: kitchen,
    name: 'Bosch Dishwasher',
    category: 'Dishwasher',
    brand: 'Bosch',
    model: 'SMS2ITW08G',
    purchase_date: dishBought,
    purchase_price: 379,
    retailer: 'John Lewis',
  });
  warranty('appliance_id', dishwasher, 'Bosch', dishBought, 2);
  const tvBought = months(-8);
  const tv = item('appliances', {
    room_id: living,
    name: 'Samsung Television',
    category: 'Television',
    brand: 'Samsung',
    model: 'QE55Q60C',
    purchase_date: tvBought,
    purchase_price: 699,
    retailer: 'Argos',
    condition: 'Excellent',
  });
  warranty('appliance_id', tv, 'Argos Care', tvBought, 1);
  const boilerBought = months(-36);
  const boiler = item('appliances', {
    room_id: hallway,
    name: 'Worcester Bosch Boiler',
    category: 'Boiler',
    brand: 'Worcester Bosch',
    model: 'Greenstar 4000',
    serial_number: 'WB-GS4-88213',
    purchase_date: boilerBought,
    purchase_price: 2450,
    retailer: 'Local installer',
    notes: 'Pressure should sit between 1 and 1.5 bar.',
  });
  warranty('appliance_id', boiler, 'Worcester Bosch', boilerBought, 10);
  if (!sample)
    item('appliances', {
      room_id: kitchen,
      name: 'Fridge Freezer',
      category: 'Fridge',
      brand: 'Hotpoint',
      model: 'H7X 93T SX',
      purchase_date: months(-60),
      purchase_price: 529,
      retailer: 'AO.com',
      condition: 'Fair',
    });

  item('inventory_items', {
    room_id: living,
    name: 'Corner Sofa',
    category: 'Furniture',
    brand: 'DFS',
    purchase_date: months(-24),
    purchase_price: 1199,
    current_value: 700,
  });
  const laptopBought = months(-10);
  const laptop = item('inventory_items', {
    room_id: bedroom,
    name: 'Work Laptop',
    category: 'Electronics',
    brand: 'Apple',
    model: 'MacBook Air 13"',
    serial_number: 'C02XK1ABCD12',
    purchase_date: laptopBought,
    purchase_price: 999,
    current_value: 800,
  });
  warranty('inventory_item_id', laptop, 'Apple', laptopBought, 1);
  if (!sample)
    item('inventory_items', {
      room_id: bedroom,
      name: 'Engagement Ring',
      category: 'Jewellery',
      purchase_date: months(-30),
      purchase_price: 1850,
      current_value: 2100,
      notes: 'Listed as a specified item on the contents policy.',
    });

  const task = (values: Row) =>
    add('maintenance_tasks', {
      ...P,
      room_id: null,
      appliance_id: null,
      series_id: null,
      description: null,
      category: null,
      recurrence: 'none',
      recurrence_interval: null,
      recurrence_unit: null,
      completed_at: null,
      notes: null,
      ...values,
    });
  task({
    room_id: hallway,
    appliance_id: boiler,
    title: 'Boiler service',
    description: 'Annual service by a Gas Safe registered engineer.',
    category: 'Heating',
    due_date: days(24),
    recurrence: 'yearly',
  });
  task({ room_id: hallway, title: 'Check smoke alarms', category: 'Safety', due_date: days(6), recurrence: 'monthly' });
  task({
    room_id: kitchen,
    appliance_id: washer,
    title: 'Clean washing machine filter',
    category: 'Cleaning',
    due_date: days(-3),
    recurrence: 'quarterly',
  });
  task({
    room_id: kitchen,
    title: 'Replace extractor fan filter',
    category: 'Cleaning',
    due_date: days(0),
    recurrence: 'biannual',
  });
  task({ title: 'Clean gutters', category: 'Exterior', due_date: days(40), recurrence: 'yearly' });
  task({
    title: 'Bleed radiators',
    category: 'Heating',
    due_date: days(-30),
    completed_at: new Date(Date.now() - 29 * 864e5).toISOString(),
  });

  const insurance = add('insurance_policies', {
    ...P,
    policy_type: sample ? 'contents' : 'home',
    provider: 'Example Insurance Co.',
    policy_number: 'HM-20931-77',
    start_date: months(-10),
    renewal_date: days(62),
    premium: 312.4,
    premium_frequency: 'yearly',
    contact_phone: '0800 000 0000',
    emergency_phone: '0800 000 0001',
    contact_email: null,
    notes: null,
  });

  const utility = (values: Row) =>
    add('utilities', {
      ...P,
      label: null,
      provider: null,
      account_number: null,
      tariff: null,
      contract_start: null,
      contract_end: null,
      monthly_cost: null,
      contact_phone: null,
      contact_email: null,
      website: null,
      notes: null,
      ...values,
    });
  utility({
    utility_type: 'Electricity',
    provider: 'Octopus Energy',
    account_number: 'A-1B2C3D4E',
    tariff: 'Flexible Octopus',
    contact_phone: '0808 164 1088',
    monthly_cost: 68,
  });
  utility({
    utility_type: 'Gas',
    provider: 'Octopus Energy',
    account_number: 'A-1B2C3D4E',
    tariff: 'Flexible Octopus',
    contact_phone: '0808 164 1088',
    monthly_cost: 54,
  });
  utility({
    utility_type: 'Water',
    provider: 'Sample Water',
    account_number: '800123456',
    tariff: 'Metered',
    monthly_cost: 32.5,
  });
  const broadband = utility({
    utility_type: 'Broadband',
    provider: 'BT',
    account_number: 'BT-99887766',
    tariff: 'Full Fibre 500',
    contract_start: months(-16),
    contract_end: days(75),
    monthly_cost: 42.99,
    contact_phone: '0800 800 150',
    website: 'bt.com',
  });

  add('council_tax', {
    ...P,
    council: 'Sampletown Borough Council',
    account_number: '600123987',
    band: sample ? 'B' : 'C',
    monthly_amount: sample ? 142.1 : 168.5,
    payment_day: 1,
    notes: 'Paid by direct debit over 10 months (April to January).',
  });

  for (let g = 0; g <= 6; g++) {
    add('meter_readings', {
      ...P,
      meter_type: 'electricity',
      reading: 21450 + g * 245 + (g % 3) * 12,
      reading_date: days(-(6 - g) * 30),
      notes: null,
    });
    add('meter_readings', {
      ...P,
      meter_type: 'gas',
      reading: 8120 + g * 118 + (g % 2) * 20,
      reading_date: days(-(6 - g) * 30),
      notes: null,
    });
  }

  add('household_members', {
    ...P,
    linked_user_id: null,
    name: 'Alex Example',
    relationship: 'Partner',
    email: 'alex@example.com',
    phone: '07700 900123',
    notes: null,
    is_emergency_contact: true,
  });
  add('household_members', {
    ...P,
    linked_user_id: null,
    name: 'Sam Example',
    relationship: 'Child',
    email: null,
    phone: null,
    notes: 'Nut allergy — EpiPen in the kitchen drawer.',
    is_emergency_contact: false,
  });

  const contact = (contact_type: string, name: string, phone: string, notes: string | null = null) =>
    add('emergency_contacts', { ...P, contact_type, name, phone, alt_phone: null, email: null, notes });
  contact('Gas emergency', 'National Gas Emergency Service', '0800 111 999', 'If you smell gas, call immediately.');
  contact('Electricity emergency', 'Power cut helpline', '105');
  contact('Water emergency', 'Sample Water emergencies', '0800 000 0002');
  contact('Plumber', "Joe's Plumbing", '07700 900456', 'Fitted the bathroom in 2022.');

  const doc = (name: string, category: string, link: Row, lines: string[]) => {
    const fileName = `${name.toLowerCase().replace(/\W+/g, '-')}.pdf`;
    const path = `${uid}/${p}/documents/${id()}-${fileName}`;
    const blob = makePdf(name, lines);
    s.__files.push([path, URL.createObjectURL(blob)]);
    add('documents', {
      ...P,
      room_id: null,
      appliance_id: null,
      inventory_item_id: null,
      maintenance_task_id: null,
      insurance_policy_id: null,
      utility_id: null,
      council_tax_id: null,
      ...link,
      name,
      category,
      file_path: path,
      file_name: fileName,
      mime_type: 'application/pdf',
      size_bytes: blob.size,
      notes: null,
      extracted_text: null,
    });
  };
  doc('Washing Machine Receipt', 'Receipts', { appliance_id: washer }, [
    'Currys',
    'Samsung WW90T534DAW washing machine',
    `Date: ${washerBought}`,
    'Total paid: GBP 449.00',
  ]);
  doc('Washing Machine Manual', 'Manuals', { appliance_id: washer }, [
    'Samsung WW90T534DAW',
    'Cleaning the debris filter: see page 42.',
  ]);
  doc('Boiler Certificate', 'Maintenance', { appliance_id: boiler }, [
    'Gas Safe benchmark certificate',
    'Worcester Bosch Greenstar 4000',
    'Installed and commissioned.',
  ]);
  doc('Home Insurance Policy', 'Insurance', { insurance_policy_id: insurance }, [
    'Example Insurance Co.',
    'Policy HM-20931-77',
    'Buildings and contents cover.',
  ]);
  doc('Broadband Contract', 'Utilities', { utility_id: broadband }, ['BT Full Fibre 500', '24 month minimum term.']);
  if (!sample) doc('Property Survey', 'Property', {}, ['RICS Level 2 survey', '24 Example Street, Sampletown AB1 2CD']);

  add('custom_fields', {
    ...P,
    entity_type: 'property',
    entity_id: p,
    label: 'Bin collection',
    value: 'Tuesday mornings (recycling fortnightly)',
    sort_order: 0,
  });
  add('custom_fields', {
    ...P,
    entity_type: 'property',
    entity_id: p,
    label: 'Wi-Fi network',
    value: 'Example-Home-5G',
    sort_order: 1,
  });

  return s;
}
