-- Run with psql connected to game_runtime; use autocommit, not BEGIN.
-- Run twice 60 seconds apart and retain both outputs. No statistics resets.
\pset pager off
\echo 'Capture time and database statistics baseline'
SELECT clock_timestamp() AS captured_at, current_database(), stats_reset,
       xact_commit, xact_rollback, tup_inserted, tup_updated, tup_deleted
FROM pg_stat_database WHERE datname=current_database();

\echo 'Current sessions; idle query text is the LAST query, not an active query'
SELECT clock_timestamp() AS captured_at, pid, usename, application_name,
       client_addr, client_port, backend_start, state, wait_event_type, wait_event,
       query_start, state_change, left(query,700) AS query
FROM pg_stat_activity
WHERE datname=current_database() AND pid<>pg_backend_pid()
ORDER BY client_addr, pid;

\echo 'Wallet checkpoint sizes and revisions (does not parse JSON)'
SELECT clock_timestamp() AS captured_at, server_id, world, record_id, revision,
       octet_length(payload) AS payload_bytes
FROM mod_data.wallet_mod_data;

\echo 'V54 mutation heads, when deployed; v1 checkpoints above are then archives'
SELECT 'SELECT clock_timestamp() AS captured_at, server_id, world, document_id, revision FROM mod_data.entity_document_state ORDER BY server_id, world, document_id'
WHERE to_regclass('mod_data.entity_document_state') IS NOT NULL
\gexec

\echo 'Table activity, including other persistence workloads'
SELECT clock_timestamp() AS captured_at, schemaname, relname, n_live_tup,
       n_dead_tup, n_tup_ins, n_tup_upd, n_tup_del, seq_scan, seq_tup_read,
       idx_scan, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_tup_upd+n_tup_ins+n_tup_del DESC LIMIT 40;

\echo 'Projection function statistics (empty unless function tracking is enabled)'
SELECT clock_timestamp() AS captured_at, schemaname, funcname, calls,
       total_time, self_time
FROM pg_stat_user_functions WHERE funcname='project_wallet_entity';

\echo 'Top statements, only when pg_stat_statements is already available'
-- Extension schema is discovered rather than assuming public.
SELECT format($q$
  SELECT clock_timestamp() AS captured_at, queryid, userid, toplevel, calls,
         total_exec_time, mean_exec_time, rows, shared_blks_hit,
         shared_blks_read, wal_bytes, left(query,1000) AS query
  FROM %I.pg_stat_statements
  WHERE dbid=(SELECT oid FROM pg_database WHERE datname=current_database())
  ORDER BY total_exec_time DESC LIMIT 30$q$, n.nspname)
FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace
WHERE e.extname='pg_stat_statements'
\gexec

-- OPTIONAL, run separately once if needed: parses each checkpoint once.
-- No full payload/item blobs are printed. {} is the empty collection format.
-- WITH docs AS MATERIALIZED (
--   SELECT server_id,world,record_id,payload::jsonb AS d
--   FROM mod_data.wallet_mod_data
-- )
-- SELECT server_id,world,record_id,c.name,count(e.key) AS entries
-- FROM docs CROSS JOIN LATERAL (VALUES
--   ('jobs',d->'jobs'),('finished',d->'finished'),('receipts',d->'receipts'),
--   ('escrow',d->'escrow'),('purchases',d->'purchases'),
--   ('pendingPurchases',d->'pendingPurchases'),
--   ('listings',d#>'{market,listings}'),
--   ('transactions',d#>'{market,transactions}'),
--   ('credits',d#>'{market,credits}'),
--   ('pendingCredits',d#>'{market,pendingCredits}')
-- ) c(name,records)
-- LEFT JOIN LATERAL jsonb_each(coalesce(c.records,'{}'::jsonb)) e ON true
-- GROUP BY server_id,world,record_id,c.name
-- ORDER BY server_id,world,c.name;

-- OPTIONAL V50-only pending errors below. After V54 these tables are archives;
-- use entity_document_record WHERE collection IN ('purchases','market.credits')
-- and payload#>>'{value,state}'='pending' for current obligations instead.
-- SELECT server_id,world,'debit' AS kind,payload->>'state' AS state,
--        payload->>'error' AS error,count(*) AS entries,
--        min((payload->>'nextAttempt')::numeric) AS min_next_attempt_ms,
--        max((payload->>'nextAttempt')::numeric) AS max_next_attempt_ms,
--        max((payload->>'attempts')::numeric) AS max_attempts
-- FROM mod_data.wallet_purchase WHERE state='pending'
-- GROUP BY server_id,world,payload->>'state',payload->>'error';
-- SELECT server_id,world,'credit' AS kind,payload->>'error' AS error,
--        count(*) AS entries
-- FROM mod_data.wallet_market_credit WHERE state='pending'
-- GROUP BY server_id,world,payload->>'error';
