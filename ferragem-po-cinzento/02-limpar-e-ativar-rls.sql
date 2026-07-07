begin;

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

commit;
