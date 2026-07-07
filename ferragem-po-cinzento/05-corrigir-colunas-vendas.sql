begin;

alter table public.vendas
  add column if not exists cliente text;

alter table public.vendas
  add column if not exists itens_json text;

alter table public.vendas
  add column if not exists criado_por uuid references auth.users(id);

commit;
