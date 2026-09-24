-- Sample data lives in its own property flagged is_sample = true, so it never
-- mixes with a user's real homes and can be removed in one go.

create or replace function public.seed_sample_home(p_user uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  prop uuid;
  kitchen uuid;
  living uuid;
  bedroom uuid;
  bathroom uuid;
  hallway uuid;
  washer uuid;
  dishwasher uuid;
  tv uuid;
  boiler uuid;
  sofa uuid;
  laptop uuid;
  home_ins uuid;
  task_boiler uuid;
begin
  insert into public.properties (user_id, name, address_line1, town, postcode, property_type, ownership_status,
                                 bedrooms, bathrooms, year_built, move_in_date, notes, is_sample)
  values (p_user, 'My Home (sample)', '24 Example Street', 'Sampletown', 'AB1 2CD', 'house', 'owner',
          3, 1, 1998, current_date - interval '4 years',
          'This is sample data to help you explore HomeHub. Delete it any time from Settings.', true)
  returning id into prop;

  insert into public.rooms (user_id, property_id, name, room_type) values (p_user, prop, 'Kitchen', 'Kitchen') returning id into kitchen;
  insert into public.rooms (user_id, property_id, name, room_type) values (p_user, prop, 'Living Room', 'Living Room') returning id into living;
  insert into public.rooms (user_id, property_id, name, room_type) values (p_user, prop, 'Main Bedroom', 'Bedroom') returning id into bedroom;
  insert into public.rooms (user_id, property_id, name, room_type) values (p_user, prop, 'Bathroom', 'Bathroom') returning id into bathroom;
  insert into public.rooms (user_id, property_id, name, room_type, notes)
    values (p_user, prop, 'Hallway', 'Hallway', 'Stopcock is under the stairs, behind the hoover.') returning id into hallway;

  insert into public.appliances (user_id, property_id, room_id, name, category, brand, model, serial_number,
                                 purchase_date, purchase_price, retailer, condition)
  values (p_user, prop, kitchen, 'Samsung Washing Machine', 'Washing machine', 'Samsung', 'WW90T534DAW', 'SN-WM-4471902',
          current_date - interval '14 months', 449.00, 'Currys', 'Good')
  returning id into washer;

  insert into public.appliances (user_id, property_id, room_id, name, category, brand, model,
                                 purchase_date, purchase_price, retailer, condition)
  values (p_user, prop, kitchen, 'Bosch Dishwasher', 'Dishwasher', 'Bosch', 'SMS2ITW08G',
          current_date - interval '23 months', 379.00, 'John Lewis', 'Good')
  returning id into dishwasher;

  insert into public.appliances (user_id, property_id, room_id, name, category, brand, model,
                                 purchase_date, purchase_price, retailer, condition)
  values (p_user, prop, living, 'Samsung Television', 'Television', 'Samsung', 'QE55Q60C',
          current_date - interval '8 months', 699.00, 'Argos', 'Excellent')
  returning id into tv;

  insert into public.appliances (user_id, property_id, room_id, name, category, brand, model, serial_number,
                                 purchase_date, purchase_price, retailer, condition, notes)
  values (p_user, prop, hallway, 'Worcester Bosch Boiler', 'Boiler', 'Worcester Bosch', 'Greenstar 4000', 'WB-GS4-88213',
          current_date - interval '3 years', 2450.00, 'Local installer', 'Good',
          'Pressure should sit between 1 and 1.5 bar.')
  returning id into boiler;

  insert into public.warranties (user_id, property_id, appliance_id, provider, start_date, expiry_date)
  values
    (p_user, prop, washer, 'Samsung', current_date - interval '14 months', current_date - interval '14 months' + interval '5 years'),
    (p_user, prop, dishwasher, 'Bosch', current_date - interval '23 months', current_date - interval '23 months' + interval '2 years'),
    (p_user, prop, tv, 'Argos Care', current_date - interval '8 months', current_date - interval '8 months' + interval '1 year'),
    (p_user, prop, boiler, 'Worcester Bosch', current_date - interval '3 years', current_date - interval '3 years' + interval '10 years');

  insert into public.inventory_items (user_id, property_id, room_id, name, category, brand, purchase_date, purchase_price, current_value)
  values (p_user, prop, living, 'Corner Sofa', 'Furniture', 'DFS', current_date - interval '2 years', 1199.00, 700.00)
  returning id into sofa;

  insert into public.inventory_items (user_id, property_id, room_id, name, category, brand, model, serial_number,
                                      purchase_date, purchase_price, current_value)
  values (p_user, prop, bedroom, 'Work Laptop', 'Electronics', 'Apple', 'MacBook Air 13"', 'C02XK1ABCD12',
          current_date - interval '10 months', 999.00, 800.00)
  returning id into laptop;

  insert into public.warranties (user_id, property_id, inventory_item_id, provider, start_date, expiry_date)
  values (p_user, prop, laptop, 'Apple', current_date - interval '10 months', current_date - interval '10 months' + interval '1 year');

  insert into public.maintenance_tasks (user_id, property_id, room_id, appliance_id, title, description, category,
                                        due_date, recurrence)
  values (p_user, prop, hallway, boiler, 'Boiler service', 'Annual service by a Gas Safe registered engineer.',
          'Heating', current_date + 24, 'yearly')
  returning id into task_boiler;

  insert into public.maintenance_tasks (user_id, property_id, room_id, title, category, due_date, recurrence)
  values
    (p_user, prop, hallway, 'Check smoke alarms', 'Safety', current_date + 6, 'monthly'),
    (p_user, prop, kitchen, 'Clean washing machine filter', 'Cleaning', current_date - 3, 'quarterly'),
    (p_user, prop, kitchen, 'Replace extractor fan filter', 'Cleaning', current_date, 'biannual'),
    (p_user, prop, null, 'Clean gutters', 'Exterior', current_date + 40, 'yearly');

  insert into public.maintenance_tasks (user_id, property_id, title, category, due_date, recurrence, completed_at)
  values (p_user, prop, 'Bleed radiators', 'Heating', current_date - 30, 'none', now() - interval '29 days');

  insert into public.insurance_policies (user_id, property_id, policy_type, provider, policy_number, start_date,
                                         renewal_date, premium, premium_frequency, contact_phone, emergency_phone)
  values (p_user, prop, 'home', 'Example Insurance Co.', 'HM-20931-77', current_date - interval '10 months',
          current_date + 62, 312.40, 'yearly', '0800 000 0000', '0800 000 0001')
  returning id into home_ins;

  insert into public.utilities (user_id, property_id, utility_type, provider, account_number, tariff, contact_phone, monthly_cost)
  values
    (p_user, prop, 'Electricity', 'Octopus Energy', 'A-1B2C3D4E', 'Flexible Octopus', '0808 164 1088', 68.00),
    (p_user, prop, 'Gas', 'Octopus Energy', 'A-1B2C3D4E', 'Flexible Octopus', '0808 164 1088', 54.00),
    (p_user, prop, 'Water', 'Sample Water', '800123456', 'Metered', null, 32.50);

  insert into public.utilities (user_id, property_id, utility_type, provider, account_number, tariff,
                                contract_start, contract_end, monthly_cost, contact_phone)
  values (p_user, prop, 'Broadband', 'BT', 'BT-99887766', 'Full Fibre 500', current_date - interval '16 months',
          current_date + 75, 42.99, '0800 800 150');

  insert into public.council_tax (user_id, property_id, council, account_number, band, monthly_amount, payment_day)
  values (p_user, prop, 'Sampletown Borough Council', '600123987', 'C', 168.50, 1);

  insert into public.meter_readings (user_id, property_id, meter_type, reading, reading_date)
  select p_user, prop, 'electricity', 21450 + g * 245 + (g % 3) * 12, (current_date - ((6 - g) * 30))
  from generate_series(0, 6) g;
  insert into public.meter_readings (user_id, property_id, meter_type, reading, reading_date)
  select p_user, prop, 'gas', 8120 + g * 118 + (g % 2) * 20, (current_date - ((6 - g) * 30))
  from generate_series(0, 6) g;

  insert into public.household_members (user_id, property_id, name, relationship, phone, is_emergency_contact)
  values
    (p_user, prop, 'Alex Example', 'Partner', '07700 900123', true),
    (p_user, prop, 'Sam Example', 'Child', null, false);

  insert into public.emergency_contacts (user_id, property_id, contact_type, name, phone, notes)
  values
    (p_user, prop, 'Gas emergency', 'National Gas Emergency Service', '0800 111 999', 'If you smell gas, call immediately.'),
    (p_user, prop, 'Electricity emergency', 'Power cut helpline', '105', null),
    (p_user, prop, 'Water emergency', 'Sample Water emergencies', '0800 000 0002', null),
    (p_user, prop, 'Plumber', 'Joe''s Plumbing', '07700 900456', 'Fitted the bathroom in 2022.');

  -- Sample documents are records only (no stored file).
  insert into public.documents (user_id, property_id, appliance_id, name, category, notes)
  values
    (p_user, prop, washer, 'Washing Machine Receipt', 'Receipts', 'Sample record — no file attached.'),
    (p_user, prop, boiler, 'Boiler Certificate', 'Maintenance', 'Sample record — no file attached.');
  insert into public.documents (user_id, property_id, insurance_policy_id, name, category, notes)
  values (p_user, prop, home_ins, 'Home Insurance Policy', 'Insurance', 'Sample record — no file attached.');

  insert into public.custom_fields (user_id, property_id, entity_type, entity_id, label, value, sort_order)
  values
    (p_user, prop, 'property', prop, 'Bin collection', 'Tuesday mornings (recycling fortnightly)', 0),
    (p_user, prop, 'property', prop, 'Wi-Fi network', 'Example-Home-5G', 1);

  return prop;
end;
$$;

revoke execute on function public.seed_sample_home(uuid) from public, anon, authenticated;

create or replace function public.create_sample_home()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if exists (select 1 from public.properties where user_id = uid and is_sample) then
    raise exception 'You already have a sample home' using errcode = 'P0001';
  end if;
  return public.seed_sample_home(uid);
end;
$$;

revoke execute on function public.create_sample_home() from public, anon;
grant execute on function public.create_sample_home() to authenticated;
