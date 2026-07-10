create extension if not exists pgcrypto;

create type waste_category as enum (
  'burnable',
  'non_burnable',
  'recyclable',
  'hazardous',
  'oversized',
  'home_appliance_recycling'
);

create table areas (
  id uuid primary key default gen_random_uuid(),
  prefecture text not null,
  municipality text not null,
  ward text,
  town text,
  postal_code text,
  timezone text not null default 'Asia/Tokyo',
  source_updated_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table official_sources (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references areas(id) on delete cascade,
  title text not null,
  url text not null,
  source_type text not null check (source_type in ('html', 'pdf')),
  fetched_at timestamptz,
  content_hash text,
  trust_status text not null default 'pending' check (trust_status in ('pending', 'verified', 'stale', 'failed')),
  created_at timestamptz not null default now()
);

create table waste_rules (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references areas(id) on delete cascade,
  category waste_category not null,
  display_name jsonb not null,
  aliases jsonb not null default '{}',
  steps jsonb not null default '{}',
  requires_washing boolean not null default false,
  requires_label_removal boolean not null default false,
  requires_cap_separation boolean not null default false,
  required_bag text,
  disposal_time text,
  disposal_location text,
  hazard_note jsonb,
  official_source_id uuid references official_sources(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table collection_days (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references areas(id) on delete cascade,
  waste_rule_id uuid not null references waste_rules(id) on delete cascade,
  weekday int check (weekday between 0 and 6),
  week_of_month int check (week_of_month between 1 and 5),
  recurrence_text text not null,
  exceptions jsonb not null default '[]',
  created_at timestamptz not null default now()
);

create table user_feedback (
  id uuid primary key default gen_random_uuid(),
  area_id uuid references areas(id) on delete set null,
  waste_rule_id uuid references waste_rules(id) on delete set null,
  locale text not null,
  message text not null,
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'rejected')),
  created_at timestamptz not null default now()
);

create table qr_pages (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references areas(id) on delete cascade,
  slug text not null unique,
  owner_name text not null,
  page_type text not null check (page_type in ('guest', 'shop', 'multi_property')),
  default_locale text not null default 'zh',
  public_note jsonb not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table qr_page_images (
  id uuid primary key default gen_random_uuid(),
  qr_page_id uuid not null references qr_pages(id) on delete cascade,
  s3_key text not null,
  content_type text not null check (content_type in ('image/jpeg', 'image/png', 'image/webp')),
  caption jsonb not null default '{}',
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index areas_lookup_idx on areas(prefecture, municipality, ward, town);
create index waste_rules_area_category_idx on waste_rules(area_id, category);
create index collection_days_area_rule_idx on collection_days(area_id, waste_rule_id);
create index qr_pages_slug_idx on qr_pages(slug);
