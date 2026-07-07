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

do $$
declare
  tabela text;
  politica record;
begin
  foreach tabela in array array['perfis','produtos','vendas','materiais','alugueis']
  loop
    for politica in
      select policyname
      from pg_policies
      where schemaname='public' and tablename=tabela
    loop
      execute format('drop policy if exists %I on public.%I',politica.policyname,tabela);
    end loop;
  end loop;
end;
$$;

alter table public.perfis enable row level security;
alter table public.produtos enable row level security;
alter table public.vendas enable row level security;
alter table public.materiais enable row level security;
alter table public.alugueis enable row level security;

alter table public.perfis force row level security;
alter table public.produtos force row level security;
alter table public.vendas force row level security;
alter table public.materiais force row level security;
alter table public.alugueis force row level security;

create policy perfis_ler
on public.perfis for select to authenticated
using(id=auth.uid() or public.e_gerencia());

create policy produtos_ler
on public.produtos for select to authenticated
using(true);

create policy produtos_gerir
on public.produtos for all to authenticated
using(public.e_gerencia())
with check(public.e_gerencia());

create policy vendas_ler
on public.vendas for select to authenticated
using(true);

create policy vendas_gerencia_alterar
on public.vendas for update to authenticated
using(public.e_gerencia())
with check(public.e_gerencia());

create policy vendas_gerencia_apagar
on public.vendas for delete to authenticated
using(public.e_gerencia());

create policy materiais_ler
on public.materiais for select to authenticated
using(true);

create policy materiais_gerir
on public.materiais for all to authenticated
using(public.e_gerencia())
with check(public.e_gerencia());

create policy alugueis_ler
on public.alugueis for select to authenticated
using(true);

create policy alugueis_criar
on public.alugueis for insert to authenticated
with check(criado_por=auth.uid());

create policy alugueis_alterar
on public.alugueis for update to authenticated
using(criado_por=auth.uid() or public.e_gerencia())
with check(criado_por=auth.uid() or public.e_gerencia());

create policy alugueis_apagar
on public.alugueis for delete to authenticated
using(public.e_gerencia());

revoke all on table public.perfis,public.produtos,public.vendas,public.materiais,public.alugueis from anon;
grant select on table public.perfis,public.produtos,public.vendas,public.materiais,public.alugueis to authenticated;
grant insert,update,delete on table public.produtos,public.vendas,public.materiais,public.alugueis to authenticated;

create or replace function public.registar_venda_segura(
  p_cliente text,
  p_pagamento text,
  p_itens jsonb
)
returns bigint
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  item jsonb;
  produto public.produtos%rowtype;
  perfil public.perfis%rowtype;
  quantidade numeric;
  total_venda numeric:=0;
  quantidade_total numeric:=0;
  compra_total numeric:=0;
  itens_guardados jsonb:='[]'::jsonb;
  nomes text:='';
  venda_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Sessão inválida';
  end if;
  if p_pagamento not in ('cash','mpesa','emola') then
    raise exception 'Método de pagamento inválido';
  end if;
  if jsonb_typeof(p_itens)<>'array' or jsonb_array_length(p_itens)=0 then
    raise exception 'A venda não contém produtos';
  end if;

  select * into perfil from public.perfis where id=auth.uid();
  if not found then raise exception 'Perfil não autorizado'; end if;

  for item in select * from jsonb_array_elements(p_itens)
  loop
    quantidade:=(item->>'qty')::numeric;
    if quantidade<=0 then raise exception 'Quantidade inválida'; end if;

    select * into produto
    from public.produtos
    where id=(item->>'produto_id')::bigint
    for update;

    if not found then raise exception 'Produto inexistente'; end if;
    if produto.qty<quantidade then
      raise exception 'Stock insuficiente: %',produto.nome;
    end if;

    update public.produtos
    set qty=qty-quantidade
    where id=produto.id;

    total_venda:=total_venda+(quantidade*produto.preco_venda);
    quantidade_total:=quantidade_total+quantidade;
    compra_total:=compra_total+(quantidade*coalesce(produto.preco_compra,0));
    nomes:=concat_ws(', ',nullif(nomes,''),produto.nome);
    itens_guardados:=itens_guardados||jsonb_build_array(jsonb_build_object(
      'id',produto.id,
      'nome',produto.nome,
      'qty',quantidade,
      'stock_qty',quantidade,
      'preco_unit',produto.preco_venda,
      'preco_compra_unit',coalesce(produto.preco_compra,0),
      'subtotal',quantidade*produto.preco_venda
    ));
  end loop;

  insert into public.vendas(
    produto_id,produto_nome,qty,total,funcionario,pagamento,
    preco_compra_unit,cliente,itens_json,criado_por
  )
  values(
    (p_itens->0->>'produto_id')::bigint,
    nomes,
    quantidade_total,
    total_venda,
    perfil.nome,
    p_pagamento,
    case when quantidade_total>0 then compra_total/quantidade_total else 0 end,
    left(coalesce(nullif(trim(p_cliente),''),'Cliente'),120),
    itens_guardados::text,
    auth.uid()
  )
  returning id into venda_id;

  return venda_id;
end;
$$;

revoke all on function public.registar_venda_segura(text,text,jsonb) from public;
grant execute on function public.registar_venda_segura(text,text,jsonb) to authenticated;

commit;
