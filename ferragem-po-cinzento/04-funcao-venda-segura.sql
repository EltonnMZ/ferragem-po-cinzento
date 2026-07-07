begin;

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
