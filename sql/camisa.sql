-- Camisa do time (rode no SQL Editor do Supabase; pode rodar de novo sem problemas)
create table if not exists public.camisa (
  id int primary key check (id = 1),
  titulo text,
  descricao text,
  valor numeric(12,2),
  foto_url text,
  whatsapp text,
  tamanhos text default 'P,M,G,GG',
  ativo boolean not null default true
);
insert into public.camisa (id, titulo) values (1, 'Camisa oficial Eternus FC') on conflict do nothing;
alter table public.camisa enable row level security;
drop policy if exists "leitura publica camisa" on public.camisa;
drop policy if exists "admin escreve camisa" on public.camisa;
create policy "leitura publica camisa" on public.camisa for select using (true);
create policy "admin escreve camisa" on public.camisa for all to authenticated using (true) with check (true);
alter table public.camisa add column if not exists foto_costas_url text;
