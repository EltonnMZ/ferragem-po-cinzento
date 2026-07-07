begin;

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

commit;
