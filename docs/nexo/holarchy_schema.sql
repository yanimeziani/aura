-- NEXO PROTOCOL · HOLARCHY SCHEMA V0.1
BEGIN;
CREATE TYPE nexo_cell_state AS ENUM ('active', 'isolated', 'soft_banned', 'hard_banned', 'recovering');
CREATE TABLE nexo_cells (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    public_key TEXT NOT NULL UNIQUE,
    state nexo_cell_state NOT NULL DEFAULT 'active',
    parent_hub_id UUID REFERENCES nexo_cells(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    behavioral_baseline_id TEXT
);
COMMIT;
