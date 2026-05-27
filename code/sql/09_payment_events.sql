-- ============================================================================
-- 09 — Payment webhook idempotency + HMAC hardening
-- ----------------------------------------------------------------------------
-- Closes audit hnag-audit-2026-05 CRITICAL: "forgeable payment webhook".
-- Webhook now requires HMAC signature verification + per-transaction
-- idempotency so a replayed POST does NOT activate premium twice.
--
-- payment_events stores every successfully-verified bank-transfer notification
-- exactly once, keyed by the bank's transaction id. Activations look this
-- table up first; duplicates are a no-op.
-- ============================================================================

CREATE TABLE IF NOT EXISTS payment_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider        TEXT NOT NULL,                -- 'sepay' | 'vnpay' | …
  external_txn_id TEXT NOT NULL,                -- bank transaction id (idempotency key)
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
  amount_vnd      INTEGER NOT NULL,
  raw_payload     JSONB NOT NULL,               -- the verified webhook body
  signature       TEXT,                         -- the verified HMAC (for forensics)
  received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at    TIMESTAMPTZ,
  status          TEXT NOT NULL DEFAULT 'received',  -- 'received'|'processed'|'unmatched'|'rejected'
  notes           TEXT,
  UNIQUE (provider, external_txn_id)
);

CREATE INDEX IF NOT EXISTS idx_payment_events_received_at
  ON payment_events (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_events_user_received
  ON payment_events (user_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_events_subscription
  ON payment_events (subscription_id);

-- Optional: a deletion-of-account cleanup view — payment_events stays around
-- for accounting/PDPL records even after the user row is soft-deleted; the
-- ON DELETE SET NULL on user_id keeps the audit trail intact.

COMMENT ON TABLE payment_events IS
  'Idempotency log for verified bank webhook events. Insert is the proof we processed this txn.';
COMMENT ON COLUMN payment_events.external_txn_id IS
  'Bank-side transaction id (SePay: id; VNPay: vnp_TransactionNo). Idempotency key.';

-- ============================================================================
-- DONE.
-- ============================================================================
