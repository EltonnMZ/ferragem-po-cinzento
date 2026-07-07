begin;

create table if not exists public.perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null,
  role text not null default 'funcionario'
    check (role in ('funcionario','gerencia')),
  criado_em timestamptz not null default now()
);

alter table public.vendas
  add column if not exists criado_por uuid references auth.users(id);
alter table public.vendas
  add column if not exists cliente text;
alter table public.vendas
  add column if not exists itens_json text;
alter table public.alugueis
  add column if not exists criado_por uuid references auth.users(id);
alter table public.alugueis
  alter column criado_por set default auth.uid();

create or replace function public.criar_perfil_novo_utilizador()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
begin
  insert into public.perfis(id,nome,role)
  values(
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'nome'),''),split_part(new.email,'@',1)),
    'funcionario'
  )
  on conflict(id) do nothing;
  return new;
end;
$$;

drop trigger if exists criar_perfil_apos_registo on auth.users;
create trigger criar_perfil_apos_registo
after insert on auth.users
for each row execute function public.criar_perfil_novo_utilizador();

create or replace function public.e_gerencia()
returns boolean
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select exists(
    select 1 from public.perfis
    where id=auth.uid() and role='gerencia'
  );
$$;

revoke all on function public.e_gerencia() from public;
grant execute on function public.e_gerencia() to authenticated;

commit;
