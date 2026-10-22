create table if not exists public.faqs (
    id uuid primary key default gen_random_uuid(),
    question text not null,
    answer text not null,
    keywords text[] not null default '{}'::text[]
);

create table if not exists public.orders (
    order_number text primary key,
    customer_phone text not null,
    status text not null,
    expected_delivery date
);

create index if not exists orders_customer_phone_idx
    on public.orders (customer_phone);

create table if not exists public.support_tickets (
    id uuid primary key default gen_random_uuid(),
    ticket_number text not null unique,
    customer_phone text not null,
    issue text not null,
    status text not null default 'open',
    created_at timestamptz not null default now()
);

create index if not exists support_tickets_customer_created_idx
    on public.support_tickets (customer_phone, created_at desc);

create table if not exists public.n8n_chat_histories (
    id serial primary key,
    session_id varchar not null,
    message jsonb not null
);

create index if not exists n8n_chat_histories_session_id_idx
    on public.n8n_chat_histories (session_id);
