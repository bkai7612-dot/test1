/**
 * Step-by-step help for every page. Shown by the "How it works" button in each
 * page header and listed together on the Help page. Keep the wording in step
 * with the buttons on screen — the steps name them exactly.
 */

export interface Guide {
  id: string;
  title: string;
  /** One line: what this page is for. */
  summary: string;
  steps: string[];
  tips?: string[];
  /** Where the Help page sends people to try it. */
  to?: string;
  group: 'Getting started' | 'Your home' | 'Belongings' | 'Upkeep' | 'Bills & cover' | 'People' | 'Your account';
}

export const GUIDES: Guide[] = [
  {
    id: 'dashboard',
    group: 'Getting started',
    title: 'Your Home screen',
    summary: 'A snapshot of your home: what needs doing next and how much you have stored.',
    to: '/',
    steps: [
      'The card at the top is your home. Tap it to see or edit its full profile.',
      'Use Quick actions to add an appliance, a document, a maintenance task or a room in one tap.',
      '"Upcoming" lists everything due soon: maintenance, warranties about to expire, insurance renewals and contracts ending. Tap any line to open it.',
      '"Home summary" counts what you have saved. Tap a tile to jump to that section.',
      'Work through the "Getting started" checklist until every box is ticked — it disappears once you are set up.',
    ],
    tips: ['Change how far ahead "Upcoming" looks in Settings → Reminders.'],
  },
  {
    id: 'properties',
    group: 'Your home',
    title: 'Properties',
    summary: 'Each home keeps its own rooms, appliances, documents and reminders.',
    to: '/properties',
    steps: [
      'Tap "Add property", give it a name (for example "My Home") and fill in the address if you like.',
      'Choose the property type and whether you own or rent it, then tap Save.',
      'When adding a new home, switch on "Add common rooms" to create a kitchen, living room, bedroom, bathroom and hallway for you.',
      'Tap a property to see its profile. Use "Switch to this property" to make it the one you are working on.',
    ],
    tips: [
      'On a computer, switch homes from the box at the top of the menu. On a phone, tap the home name at the top of the screen.',
      'The free plan includes one property. Homefolio Plus adds unlimited properties.',
    ],
  },
  {
    id: 'property-detail',
    group: 'Your home',
    title: 'Property profile',
    summary: 'The key facts about one home, plus anything else worth remembering.',
    to: '/properties',
    steps: [
      'Tap Edit to change the name, address, bedrooms, year built or move-in date.',
      'Under "Extra details", tap Add to save anything else — bin day, Wi-Fi name, where the stopcock is.',
      'To keep the survey, deeds or tenancy agreement, go to Documents, tap Upload and choose "Whole property" under "Attach to".',
      'Add photos of the outside and each room — useful for insurance and moving out.',
    ],
    tips: ['"Delete property" removes everything stored for that home, including its files. It cannot be undone.'],
  },
  {
    id: 'rooms',
    group: 'Your home',
    title: 'Rooms',
    summary: 'See what is where: appliances, possessions, photos and notes, room by room.',
    to: '/rooms',
    steps: [
      'Tap "Add room", pick the type of room and give it a name (for example "Main bedroom").',
      'Add notes such as the paint colour or where the fuse box is, then tap Save.',
      'Open a room to see the appliances and inventory in it. Use the Add button in each list to add something straight into that room.',
      'Add photos so you remember how the room looked.',
    ],
  },
  {
    id: 'room-detail',
    group: 'Your home',
    title: 'A room',
    summary: 'Everything in one room.',
    to: '/rooms',
    steps: [
      'The Appliances and Inventory lists show what you have placed in this room. Tap Add to put something new here.',
      'Upload documents that belong to the room, such as a flooring receipt.',
      'Tap Edit to rename the room or change its notes, and use "Extra details" for anything else, like the paint colour.',
      'Add photos so you remember how the room looked.',
    ],
  },
  {
    id: 'appliances',
    group: 'Belongings',
    title: 'Appliances',
    summary: 'Your boiler, washing machine, fridge and more — with models, receipts and warranties.',
    to: '/appliances',
    steps: [
      'Tap "Add appliance". Type a name, then choose the category and the room it is in.',
      'Add the brand, model and serial number. They are usually on a sticker on the back or inside the door.',
      'Add the purchase date, price and retailer, then tap Save.',
      'Open the appliance and tap "Add warranty" to record how long it is covered — Homefolio reminds you before it runs out.',
      'Upload the receipt and manual, add photos, and tap "Add task" for jobs like "Descale" or "Annual service".',
    ],
    tips: ['Use the search box and the room and category filters to find something quickly.'],
  },
  {
    id: 'appliance-detail',
    group: 'Belongings',
    title: 'An appliance',
    summary: 'Everything about one appliance in one place.',
    to: '/appliances',
    steps: [
      'Tap Edit to change the details.',
      'Tap "Add warranty" and enter the start and expiry dates and the provider.',
      'Under Documents, tap Upload to add the receipt or manual.',
      'Under Maintenance, tap "Add task" to set a reminder linked to this appliance.',
      'Add photos, including one of the model sticker.',
    ],
  },
  {
    id: 'inventory',
    group: 'Belongings',
    title: 'Inventory',
    summary: 'A record of your possessions and what they are worth — handy for insurance claims.',
    to: '/inventory',
    steps: [
      'Tap "Add item" and give it a name, for example "Sony television".',
      'Choose a category and a room, and add the brand and serial number if it has one.',
      'Add what you paid and what it is worth now, then tap Save.',
      'Open the item to add photos, upload the receipt or add a warranty.',
    ],
    tips: ['Photograph valuables and keep receipts here. If you ever need to claim, everything is ready.'],
  },
  {
    id: 'inventory-detail',
    group: 'Belongings',
    title: 'An inventory item',
    summary: 'The details, value, photos and receipt for one possession.',
    to: '/inventory',
    steps: [
      'Tap Edit to update its value or condition.',
      'Tap "Add warranty" if it is still covered.',
      'Upload the receipt and add photos from a couple of angles.',
    ],
  },
  {
    id: 'warranties',
    group: 'Belongings',
    title: 'Warranties',
    summary: 'See at a glance what is still covered and what is about to run out.',
    to: '/warranties',
    steps: [
      'Warranties are added from an appliance or inventory item: open it and tap "Add warranty".',
      'This page lists them all. Use the filters to see only those expiring soon or already expired.',
      'Tap a warranty to open the item it belongs to.',
    ],
    tips: ['Homefolio reminds you before a warranty expires, so you can get repairs done while they are free.'],
  },
  {
    id: 'documents',
    group: 'Belongings',
    title: 'Documents',
    summary: 'Receipts, manuals, certificates and policies — always to hand.',
    to: '/documents',
    steps: [
      'Tap Upload and choose a file (PDF, photo, Word or text, up to 20 MB). On a phone you can take a photo of a paper receipt.',
      'Give it a clear name, such as "Washing machine receipt", and pick a category.',
      'Under "Attach to", link it to an appliance, item, task, policy or utility — it will then show on that page too.',
      'Tap Upload. Tap any document later to view, download, share or edit it.',
    ],
    tips: ['Use the search box and category chips to find a document in seconds.'],
  },
  {
    id: 'maintenance',
    group: 'Upkeep',
    title: 'Maintenance',
    summary: 'Simple reminders that keep your home in good shape.',
    to: '/maintenance',
    steps: [
      'Tap "Add task" and type what needs doing, for example "Boiler service".',
      'Pick the due date. Under Repeat, choose how often it comes round — yearly, every 6 months, monthly or a custom gap.',
      'Link it to an appliance if it is for one, then tap Save.',
      'When it is done, tick the circle next to the task. A repeating task schedules the next one for you.',
      'Use the chips at the top to see what is to do, overdue, due today, upcoming or completed.',
    ],
    tips: [
      'Good ones to start with: boiler service (yearly), test smoke alarms (monthly), clean gutters (every 6 months).',
      'On the phone apps you get a notification on the morning a task is due.',
    ],
  },
  {
    id: 'maintenance-detail',
    group: 'Upkeep',
    title: 'A maintenance task',
    summary: 'The details and paperwork for one job.',
    to: '/maintenance',
    steps: [
      'Tap "Mark as done" when the job is finished. Tap "Mark as not done" if you ticked it by mistake.',
      'Tap Edit to change the date, how often it repeats or the notes.',
      'Upload the invoice or certificate under Documents, and add before-and-after photos.',
    ],
  },
  {
    id: 'meter-readings',
    group: 'Upkeep',
    title: 'Meter readings',
    summary: 'A simple history of your electricity, gas and water meters.',
    to: '/meter-readings',
    steps: [
      'Choose the meter at the top: Electricity, Gas or Water.',
      'Tap "Add reading", enter the number on the meter and the date, then tap Save. Add a photo of the meter as proof if you like.',
      'After two readings you will see how much you used between them, and a chart.',
    ],
    tips: ['Take a reading when you move in, when you switch supplier and when a bill arrives, to check it is right.'],
  },
  {
    id: 'utilities',
    group: 'Bills & cover',
    title: 'Utilities',
    summary: 'Energy, water, broadband and other services for this home.',
    to: '/utilities',
    steps: [
      'Tap one of the dashed boxes (for example "Add electricity") or the Add button at the top.',
      'Enter the provider, account number, tariff and monthly cost.',
      'Add the contract start and end dates — Homefolio reminds you before the contract ends so you can shop around.',
      'Tap a utility to see it, upload bills and contracts, or tap its phone number to call.',
    ],
    tips: ["Homefolio doesn't connect to your providers. It's a tidy place for your own records."],
  },
  {
    id: 'utility-detail',
    group: 'Bills & cover',
    title: 'A utility',
    summary: 'The account details and paperwork for one service.',
    to: '/utilities',
    steps: ['Tap Edit to update the tariff, cost or contract dates.', 'Upload bills and contracts under "Bills & contracts".'],
  },
  {
    id: 'council-tax',
    group: 'Bills & cover',
    title: 'Council tax',
    summary: 'Your council, account number, band and payment date, handy when you need them.',
    to: '/council-tax',
    steps: [
      'Tap "Add council tax details".',
      'Enter your council, your account or reference number, your band, the monthly amount and the payment day. Tap Save.',
      'Upload your bill and letters under "Bills & letters".',
    ],
  },
  {
    id: 'insurance',
    group: 'Bills & cover',
    title: 'Insurance',
    summary: 'Your home, contents and buildings policies, renewal dates and who to call.',
    to: '/insurance',
    steps: [
      'Tap "Add policy" and choose the type of cover — home, contents, buildings, boiler cover and more.',
      'Enter the provider, policy number, renewal date and the "Claims / emergency phone" number. Tap Save.',
      'Open the policy and upload the policy document.',
      'Homefolio reminds you before it renews, so you have time to compare prices.',
    ],
    tips: ['The claims number also appears on the Emergency page, where it is easy to find in a hurry.'],
  },
  {
    id: 'insurance-detail',
    group: 'Bills & cover',
    title: 'A policy',
    summary: 'Everything about one insurance policy.',
    to: '/insurance',
    steps: ['Tap Edit to update the renewal date or premium.', 'Upload the policy schedule under "Policy documents".'],
  },
  {
    id: 'household',
    group: 'People',
    title: 'Household',
    summary: 'The people who live here and how to reach them.',
    to: '/household',
    steps: [
      'Tap "Add person" and enter their name and how they are related to you.',
      'Add a phone number and email, and any notes, such as allergies.',
      'Switch on "Emergency contact" to also show them on the Emergency page. Tap Save.',
    ],
  },
  {
    id: 'emergency',
    group: 'People',
    title: 'Emergency',
    summary: 'Important numbers for this home, ready when you need them.',
    to: '/emergency',
    steps: [
      'The UK national numbers are already here: 999, the gas emergency line, 105 for power cuts and 111 for the NHS.',
      'Tap "Add contact" to save your plumber, electrician, landlord or water company. Tap Save.',
      'Tap Call on any contact to ring them straight away from your phone.',
    ],
    tips: ["Your insurers' claims lines and household members marked as emergency contacts appear here automatically."],
  },
  {
    id: 'search',
    group: 'Getting started',
    title: 'Search',
    summary: 'Find anything across your home in seconds.',
    to: '/search',
    steps: [
      'Tap the search box at the top of any screen.',
      'Type at least two letters — a brand, a model, a name or a word from a document.',
      'Use the chips to narrow the results, or switch between "This property" and "All properties".',
      'Tap a result to open it.',
    ],
  },
  {
    id: 'settings',
    group: 'Your account',
    title: 'Settings',
    summary: 'Your plan, account, reminders, appearance and data.',
    to: '/settings',
    steps: [
      'Your plan: see how much storage you have used, and upgrade to Homefolio Plus.',
      'Account and Password: change your name, email or password.',
      'Reminders: choose what shows in "Upcoming" and how far ahead it looks.',
      'Appearance: choose light, dark or match your device.',
      'Your data: download a copy of everything, add or remove the sample home, or delete your account.',
    ],
  },
  {
    id: 'upgrade',
    group: 'Your account',
    title: 'Homefolio Plus',
    summary: 'More room for your home, and no sponsored cards.',
    to: '/upgrade',
    steps: [
      'Choose monthly, yearly or lifetime.',
      'Tap the button to pay through the App Store, Google Play or your browser.',
      'Plus switches on in a moment on every device you sign in to.',
      'Changed phone? Tap "Restore purchases".',
    ],
    tips: ['Everything in the free plan stays free.'],
  },
  {
    id: 'admin',
    group: 'Your account',
    title: 'Advertising (admins only)',
    summary: 'Add the sponsored cards you sell and send advertisers their numbers.',
    to: '/admin',
    steps: [
      'Tap "New campaign" and enter the advertiser, headline, text, button text and link.',
      'Choose where it shows (Home screen, Maintenance, Appliances, Utilities or Insurance), the dates and the price. Tap Save.',
      'Tap "Upload logo" to add their logo.',
      'Each month, pick the month under "Monthly report" and tap "Copy summary" to send the advertiser their views and clicks.',
    ],
  },
  {
    id: 'more',
    group: 'Getting started',
    title: 'More',
    summary: 'Every section that is not in the bar at the bottom.',
    to: '/more',
    steps: ['Tap any section to open it. Home, Properties, Maintenance and Documents are always in the bar at the bottom.'],
  },
];

const ROUTES: [RegExp, string][] = [
  [/^\/$/, 'dashboard'],
  [/^\/properties\/[^/]+$/, 'property-detail'],
  [/^\/properties$/, 'properties'],
  [/^\/rooms\/[^/]+$/, 'room-detail'],
  [/^\/rooms$/, 'rooms'],
  [/^\/appliances\/[^/]+$/, 'appliance-detail'],
  [/^\/appliances$/, 'appliances'],
  [/^\/inventory\/[^/]+$/, 'inventory-detail'],
  [/^\/inventory$/, 'inventory'],
  [/^\/warranties$/, 'warranties'],
  [/^\/documents$/, 'documents'],
  [/^\/maintenance\/[^/]+$/, 'maintenance-detail'],
  [/^\/maintenance$/, 'maintenance'],
  [/^\/meter-readings$/, 'meter-readings'],
  [/^\/utilities\/[^/]+$/, 'utility-detail'],
  [/^\/utilities$/, 'utilities'],
  [/^\/council-tax$/, 'council-tax'],
  [/^\/insurance\/[^/]+$/, 'insurance-detail'],
  [/^\/insurance$/, 'insurance'],
  [/^\/household$/, 'household'],
  [/^\/emergency$/, 'emergency'],
  [/^\/search$/, 'search'],
  [/^\/settings$/, 'settings'],
  [/^\/upgrade$/, 'upgrade'],
  [/^\/admin$/, 'admin'],
  [/^\/more$/, 'more'],
];

export function guideForPath(pathname: string): Guide | null {
  const match = ROUTES.find(([re]) => re.test(pathname));
  return match ? (GUIDES.find((g) => g.id === match[1]) ?? null) : null;
}
