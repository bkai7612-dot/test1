import {
  AirVent,
  Bath,
  BedDouble,
  Car,
  CookingPot,
  DoorOpen,
  Flame,
  Heater,
  Laptop,
  Microwave,
  Package,
  Refrigerator,
  Snowflake,
  Sofa,
  Trees,
  Tv,
  WashingMachine,
  Wind,
  Utensils,
  Shirt,
  Gem,
  Hammer,
  Dumbbell,
  Zap,
  Flame as GasIcon,
  Droplets,
  Wifi,
  Plug,
  type LucideIcon,
} from 'lucide-react';

const ROOM_ICONS: Record<string, LucideIcon> = {
  kitchen: CookingPot,
  bedroom: BedDouble,
  bathroom: Bath,
  'living room': Sofa,
  garden: Trees,
  garage: Car,
  hallway: DoorOpen,
};

export function roomIcon(type: string | null | undefined): LucideIcon {
  return ROOM_ICONS[(type ?? '').toLowerCase()] ?? DoorOpen;
}

const ITEM_ICONS: Record<string, LucideIcon> = {
  'washing machine': WashingMachine,
  dishwasher: Utensils,
  fridge: Refrigerator,
  freezer: Snowflake,
  oven: CookingPot,
  microwave: Microwave,
  television: Tv,
  computer: Laptop,
  boiler: Flame,
  heating: Heater,
  'air conditioning': AirVent,
  'vacuum cleaner': Wind,
  electronics: Laptop,
  furniture: Sofa,
  kitchen: Utensils,
  clothing: Shirt,
  jewellery: Gem,
  tools: Hammer,
  sports: Dumbbell,
};

export function itemIcon(category: string | null | undefined, fallback: LucideIcon = Package): LucideIcon {
  return ITEM_ICONS[(category ?? '').toLowerCase()] ?? fallback;
}

const UTILITY_ICONS: Record<string, LucideIcon> = {
  electricity: Zap,
  gas: GasIcon,
  water: Droplets,
  broadband: Wifi,
};

export function utilityIcon(type: string | null | undefined): LucideIcon {
  return UTILITY_ICONS[(type ?? '').toLowerCase()] ?? Plug;
}
