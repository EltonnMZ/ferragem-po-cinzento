# Ativar autenticação e proteção

## Forma mais fácil: executar por partes

No Supabase, abra **SQL Editor** e execute estes arquivos nesta ordem:

1. `01-criar-perfis-e-funcoes.sql`
2. `02-limpar-e-ativar-rls.sql`
3. `03-politicas-e-permissoes.sql`
4. `04-funcao-venda-segura.sql`
5. `05-corrigir-colunas-vendas.sql` — use este se aparecer erro de coluna em `vendas`, como `cliente` ou `itens_json`.

Em cada arquivo:

1. Abra o arquivo.
2. Selecione tudo com `Ctrl + A`.
3. Copie com `Ctrl + C`.
4. Cole no Supabase SQL Editor com `Ctrl + V`.
5. Clique em **Run**.

O arquivo completo `supabase-security.sql` continua disponível, caso prefira executar tudo de uma só vez.

## Depois do SQL

1. Em **Authentication → Providers → Email**, ative e-mail/senha.
2. Em **Authentication → Users**, crie cada utilizador com senha forte.
3. O perfil inicial é sempre `funcionario`. Para promover a conta da gerência, execute:

```sql
update public.perfis
set nome='Gerência', role='gerencia'
where id=(select id from auth.users where email='EMAIL_DA_GERENCIA');
```

4. Para dar o nome correto aos funcionários:

```sql
update public.perfis
set nome='Nome do funcionário'
where id=(select id from auth.users where email='EMAIL_DO_FUNCIONARIO');
```

## Importante

- Faça uma cópia de segurança da base antes de executar.
- Não coloque senha nem chave `service_role` no HTML.
- A chave pública `sb_publishable_...` pode permanecer no frontend; a proteção efetiva vem da sessão autenticada e das políticas RLS.
- O novo registo de venda usa `registar_venda_segura`, que valida o preço e bloqueia o stock dentro de uma única transação.
- Teste primeiro numa cópia da base, pois a migração remove políticas RLS antigas dessas cinco tabelas.
