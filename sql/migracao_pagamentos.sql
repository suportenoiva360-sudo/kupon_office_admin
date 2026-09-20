-- ============================================================================
-- Feature 4 — Gestão de pagamentos (Transferência / Mobile Money / Multicaixa
-- Express). Aplica manualmente no dashboard do Supabase (SQL Editor) — o repo
-- não tem pasta supabase/, segue-se o padrão das migrações anteriores.
--
-- Objectivo: pedidos de pagamento criados pelo utilizador ficam `pending` e só
-- reflectem na conta dele APÓS aprovação do admin (RPC atómico: muda o status
-- E credita/dedita na wallet na MESMA transacção).
-- ============================================================================

-- 1. Tabela de pedidos de pagamento (métodos: transferência bancária,
--    mobile money e multicaixa express — todos precisam de aprovação admin).
create table if not exists public.payment_requests (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  method      text not null check (method in
                ('transferencia','mobile_money','multicaixa_express')),
  direction   text not null default 'saque' check (direction in
                ('saque','recarga')),
  amount      numeric(12,2) not null check (amount > 0),
  reference   text,                 -- IBAN / telefone / terminal
  status      text not null default 'pending' check (status in
                ('pending','approved','rejected')),
  created_at  timestamptz not null default now(),
  processed_at timestamptz,
  admin_id    uuid references auth.users(id) on delete set null,
  updated_at  timestamptz not null default now()
);

comment on table public.payment_requests is
  'Pedidos de pagamento do utilizador que exigem aprovação administrativa '
  'antes de reflectirem na conta.';

alter table public.payment_requests enable row level security;

create policy "payment_requests_admin_full"
  on public.payment_requests for all
  to authenticated
  using (
    coalesce((select (auth.jwt() -> 'app_metadata' -> 'is_admin')::boolean),
             false)
  )
  with check (
    coalesce((select (auth.jwt() -> 'app_metadata' -> 'is_admin')::boolean),
             false)
  );

create policy "payment_requests_user_insert_own"
  on public.payment_requests for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "payment_requests_user_select_own"
  on public.payment_requests for select
  to authenticated
  using (auth.uid() = user_id);

-- 2. RPC atómico de decisão (aprovar/rejeitar) — uma única transacção:
--    muda o status E, no caso de aprovação de recarga, credita na wallet.
create or replace function public.decide_payment_request(
  p_request_id uuid,
  p_decision  text,          -- 'approved' | 'rejected'
  p_admin_id  uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.payment_requests%rowtype;
  v_is_admin boolean;
begin
  select coalesce(
    (select (auth.jwt() -> 'app_metadata' -> 'is_admin')::boolean), false
  ) into v_is_admin;
  if not v_is_admin then
    raise exception 'Apenas administradores podem decidir pedidos de pagamento.';
  end if;

  select * into v_req
  from public.payment_requests
  where id = p_request_id
  for update;   -- bloqueia pedido concorrente do admin

  if not found then
    raise exception 'Pedido de pagamento não encontrado.';
  end ifval;

  if v_req.status <> 'pending' then
    raise exception 'Pedido já processado (estado: %)', v_req.status;
  end if;

  if p_decision = 'approved' then
    if v_req.direction = 'recarga' then
      -- credita a wallet do utilizador na mesma transacção (atómicamente)
      perform public.add_credits(
        p_user_id    := v_req.user_id,
        p_amount     := p_amount_as_int(v_req.amount),
        p_description := 'Pagamento aprovado (' || v_req.method || ')',
        p_type       := 'mobile_money'
      );
    end if;

    update public.payment_requests
       set status = 'approved',
           processed_at = now(),
           admin_id = p_admin_id,
           updated_at = now()
     where id = p_request_id;
  elsif p_decision = 'rejected' then
    update public.payment_requests
       set status = 'rejected',
           processed_at = now(),
           admin_id = p_admin_id,
           updated_at = now()
     where id = p_request_id;
  else
    raise exception 'Decisão inválida (deve ser approved ou rejected).';
  end if;
end;
$$;

revoke all on function public.decide_payment_request(uuid, text, uuid)
  from public;
grant execute on function public.decide_payment_request(uuid, text, uuid)
  to authenticated;
