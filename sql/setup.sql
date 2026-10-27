-- Execute no Supabase: SQL Editor > New query > Run  (pode rodar novamente sem problemas)
create table if not exists public.jogadores (
  id bigint generated always as identity primary key,
  nome text not null,
  numero int,
  posicao text not null default 'Ala',
  foto_url text,
  ativo boolean not null default true,
  criado_em timestamptz default now()
);
alter table public.jogadores add column if not exists idade int;
alter table public.jogadores add column if not exists altura_cm int;
alter table public.jogadores add column if not exists pe_dominante text;

create table if not exists public.contato (
  id int primary key check (id = 1),
  email text, telefone text, whatsapp text, instagram text,
  endereco text, treinos text
);
insert into public.contato (id, treinos) values (1, 'Terças e quintas, 20h') on conflict do nothing;

alter table public.jogadores enable row level security;
alter table public.contato enable row level security;

drop policy if exists "leitura publica jogadores" on public.jogadores;
drop policy if exists "leitura publica contato" on public.contato;
drop policy if exists "admin escreve jogadores" on public.jogadores;
drop policy if exists "admin escreve contato" on public.contato;
create policy "leitura publica jogadores" on public.jogadores for select using (true);
create policy "leitura publica contato" on public.contato for select using (true);
create policy "admin escreve jogadores" on public.jogadores for all to authenticated using (true) with check (true);
create policy "admin escreve contato" on public.contato for all to authenticated using (true) with check (true);

-- Fotos dos jogadores (leitura pública; só o admin envia/apaga)
insert into storage.buckets (id, name, public) values ('fotos', 'fotos', true) on conflict (id) do update set public = true;
drop policy if exists "fotos leitura" on storage.objects;
drop policy if exists "fotos admin insere" on storage.objects;
drop policy if exists "fotos admin altera" on storage.objects;
drop policy if exists "fotos admin apaga" on storage.objects;
create policy "fotos leitura" on storage.objects for select using (bucket_id = 'fotos');
create policy "fotos admin insere" on storage.objects for insert to authenticated with check (bucket_id = 'fotos');
create policy "fotos admin altera" on storage.objects for update to authenticated using (bucket_id = 'fotos');
create policy "fotos admin apaga" on storage.objects for delete to authenticated using (bucket_id = 'fotos');

-- Configurações do site (logo do time)
create table if not exists public.configuracoes (
  id int primary key check (id = 1),
  logo_url text
);
insert into public.configuracoes (id) values (1) on conflict do nothing;
alter table public.configuracoes enable row level security;
drop policy if exists "leitura publica config" on public.configuracoes;
drop policy if exists "admin escreve config" on public.configuracoes;
create policy "leitura publica config" on public.configuracoes for select using (true);
create policy "admin escreve config" on public.configuracoes for all to authenticated using (true) with check (true);

-- Financeiro (somente o admin acessa)
create table if not exists public.movimentacoes (
  id bigint generated always as identity primary key,
  tipo text not null check (tipo in ('entrada','saida')),
  valor numeric(12,2) not null check (valor > 0),
  descricao text,
  data date not null default current_date,
  quem_tipo text not null default 'time' check (quem_tipo in ('time','jogador','externo')),
  quem_nome text,
  criado_em timestamptz default now()
);
create table if not exists public.desejos (
  id bigint generated always as identity primary key,
  item text not null,
  valor numeric(12,2) not null default 0,
  comprado boolean not null default false,
  criado_em timestamptz default now()
);
alter table public.movimentacoes enable row level security;
alter table public.desejos enable row level security;
drop policy if exists "admin movimentacoes" on public.movimentacoes;
drop policy if exists "admin desejos" on public.desejos;
create policy "admin movimentacoes" on public.movimentacoes for all to authenticated using (true) with check (true);
create policy "admin desejos" on public.desejos for all to authenticated using (true) with check (true);

-- Mensalidades
alter table public.jogadores add column if not exists isento boolean not null default false;
alter table public.configuracoes add column if not exists mensalidade_valor numeric(12,2) not null default 0;
alter table public.configuracoes add column if not exists mensalidade_dia int not null default 10;

-- Uma linha aqui = mensalidade paga (jogador + mês). Pendente/atrasado é calculado pelo site.
create table if not exists public.mensalidades (
  id bigint generated always as identity primary key,
  jogador_id bigint not null references public.jogadores(id) on delete cascade,
  mes date not null,
  valor numeric(12,2) not null,
  pago_em date not null default current_date,
  movimentacao_id bigint references public.movimentacoes(id) on delete cascade,
  unique (jogador_id, mes)
);
-- Ajustes de um mês específico: sem mensalidade e/ou valor diferente do padrão
create table if not exists public.mensalidade_meses (
  mes date primary key,
  sem_mensalidade boolean not null default false,
  valor numeric(12,2)
);
alter table public.mensalidades enable row level security;
alter table public.mensalidade_meses enable row level security;
drop policy if exists "admin mensalidades" on public.mensalidades;
drop policy if exists "admin mensalidade_meses" on public.mensalidade_meses;
create policy "admin mensalidades" on public.mensalidades for all to authenticated using (true) with check (true);
create policy "admin mensalidade_meses" on public.mensalidade_meses for all to authenticated using (true) with check (true);

-- Pagar: registra a mensalidade e a entrada no financeiro de uma vez só
create or replace function public.pagar_mensalidade(p_jogador bigint, p_mes date, p_valor numeric, p_data date)
returns void language plpgsql as $$
declare v_nome text; v_mov bigint;
begin
  select nome into v_nome from public.jogadores where id = p_jogador;
  if v_nome is null then raise exception 'Jogador não encontrado'; end if;
  if exists (select 1 from public.mensalidades where jogador_id = p_jogador and mes = p_mes) then
    raise exception 'Esta mensalidade já está paga';
  end if;
  insert into public.movimentacoes (tipo, valor, descricao, data, quem_tipo, quem_nome)
    values ('entrada', p_valor, 'Mensalidade ' || to_char(p_mes, 'MM/YYYY'), p_data, 'jogador', v_nome)
    returning id into v_mov;
  insert into public.mensalidades (jogador_id, mes, valor, pago_em, movimentacao_id)
    values (p_jogador, p_mes, p_valor, p_data, v_mov);
end $$;

-- Desfazer: remove a mensalidade e a entrada correspondente no financeiro
create or replace function public.desfazer_mensalidade(p_jogador bigint, p_mes date)
returns void language plpgsql as $$
begin
  delete from public.movimentacoes where id = (select movimentacao_id from public.mensalidades where jogador_id = p_jogador and mes = p_mes);
  delete from public.mensalidades where jogador_id = p_jogador and mes = p_mes;
end $$;

revoke all on function public.pagar_mensalidade(bigint, date, numeric, date) from public, anon;
revoke all on function public.desfazer_mensalidade(bigint, date) from public, anon;
grant execute on function public.pagar_mensalidade(bigint, date, numeric, date) to authenticated;
grant execute on function public.desfazer_mensalidade(bigint, date) to authenticated;
