-- Jogos (rode no SQL Editor do Supabase; pode rodar de novo sem problemas)
create table if not exists public.jogos (
  id bigint generated always as identity primary key,
  adversario text not null,
  data date not null,
  hora time,
  local text,
  competicao text,
  status text not null default 'agendado' check (status in ('agendado','encerrado')),
  observacoes text,
  criado_em timestamptz default now()
);
-- Quem entrou na escalação: titular = true, reserva = false
create table if not exists public.jogo_escalacao (
  jogo_id bigint not null references public.jogos(id) on delete cascade,
  jogador_id bigint not null references public.jogadores(id) on delete cascade,
  titular boolean not null default true,
  primary key (jogo_id, jogador_id)
);
-- Gols: do Eternus (autor + assistência opcional) ou do adversário (só minuto)
create table if not exists public.gols (
  id bigint generated always as identity primary key,
  jogo_id bigint not null references public.jogos(id) on delete cascade,
  tipo text not null check (tipo in ('eternus','adversario')),
  minuto int check (minuto between 0 and 200),
  autor_id bigint references public.jogadores(id) on delete set null,
  assistencia_id bigint references public.jogadores(id) on delete set null
);
alter table public.jogos enable row level security;
alter table public.jogo_escalacao enable row level security;
alter table public.gols enable row level security;
drop policy if exists "leitura publica jogos" on public.jogos;
drop policy if exists "leitura publica escalacao" on public.jogo_escalacao;
drop policy if exists "leitura publica gols" on public.gols;
drop policy if exists "admin jogos" on public.jogos;
drop policy if exists "admin escalacao" on public.jogo_escalacao;
drop policy if exists "admin gols" on public.gols;
create policy "leitura publica jogos" on public.jogos for select using (true);
create policy "leitura publica escalacao" on public.jogo_escalacao for select using (true);
create policy "leitura publica gols" on public.gols for select using (true);
create policy "admin jogos" on public.jogos for all to authenticated using (true) with check (true);
create policy "admin escalacao" on public.jogo_escalacao for all to authenticated using (true) with check (true);
create policy "admin gols" on public.gols for all to authenticated using (true) with check (true);

-- Estatísticas de cada jogador: calculadas na hora, só de jogos encerrados (sempre atualizadas)
create or replace view public.jogador_stats as
select j.id as jogador_id,
  (select count(*) from public.jogo_escalacao e join public.jogos g on g.id = e.jogo_id
     where e.jogador_id = j.id and g.status = 'encerrado') as jogos,
  (select count(*) from public.jogo_escalacao e join public.jogos g on g.id = e.jogo_id
     where e.jogador_id = j.id and e.titular and g.status = 'encerrado') as titular,
  (select count(*) from public.gols x join public.jogos g on g.id = x.jogo_id
     where x.autor_id = j.id and x.tipo = 'eternus' and g.status = 'encerrado') as gols,
  (select count(*) from public.gols x join public.jogos g on g.id = x.jogo_id
     where x.assistencia_id = j.id and x.tipo = 'eternus' and g.status = 'encerrado') as assistencias
from public.jogadores j;
grant select on public.jogador_stats to anon, authenticated;

-- Salva jogo + escalação + gols de uma vez só (tudo ou nada)
create or replace function public.salvar_jogo(p_id bigint, p_jogo jsonb, p_escalacao jsonb, p_gols jsonb)
returns bigint language plpgsql as $$
declare v_id bigint;
begin
  if p_id is null then
    insert into public.jogos (adversario, data, hora, local, competicao, status, observacoes)
    values (p_jogo->>'adversario', (p_jogo->>'data')::date, nullif(p_jogo->>'hora','')::time, nullif(p_jogo->>'local',''),
            nullif(p_jogo->>'competicao',''), p_jogo->>'status', nullif(p_jogo->>'observacoes',''))
    returning id into v_id;
  else
    update public.jogos set adversario = p_jogo->>'adversario', data = (p_jogo->>'data')::date,
      hora = nullif(p_jogo->>'hora','')::time, local = nullif(p_jogo->>'local',''),
      competicao = nullif(p_jogo->>'competicao',''), status = p_jogo->>'status',
      observacoes = nullif(p_jogo->>'observacoes','')
    where id = p_id returning id into v_id;
    if v_id is null then raise exception 'Jogo não encontrado'; end if;
  end if;
  delete from public.jogo_escalacao where jogo_id = v_id;
  delete from public.gols where jogo_id = v_id;
  insert into public.jogo_escalacao (jogo_id, jogador_id, titular)
    select v_id, x.jogador_id, coalesce(x.titular, true)
    from jsonb_to_recordset(coalesce(p_escalacao, '[]'::jsonb)) as x(jogador_id bigint, titular boolean);
  insert into public.gols (jogo_id, tipo, minuto, autor_id, assistencia_id)
    select v_id, x.tipo, x.minuto, x.autor_id, x.assistencia_id
    from jsonb_to_recordset(coalesce(p_gols, '[]'::jsonb)) as x(tipo text, minuto int, autor_id bigint, assistencia_id bigint);
  return v_id;
end $$;
revoke all on function public.salvar_jogo(bigint, jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.salvar_jogo(bigint, jsonb, jsonb, jsonb) to authenticated;
