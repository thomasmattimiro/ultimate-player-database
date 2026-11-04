create or replace view public.import_batch_summary with (security_invoker = true) as
 SELECT b.id,
    b.data_source_id,
    ds.name AS data_source_name,
    b.status,
    b.started_at,
    b.completed_at,
    b.records_seen,
    b.records_created,
    b.records_updated,
    b.records_rejected,
    b.error_summary,
    b.metadata,
    b.created_at,
    count(ir.id) AS staged_record_count,
    count(ir.id) FILTER (WHERE ir.processing_status = 'received'::text) AS received_count,
    count(ir.id) FILTER (WHERE ir.processing_status = 'normalized'::text) AS normalized_count,
    count(ir.id) FILTER (WHERE ir.processing_status = 'needs_review'::text) AS needs_review_count,
    count(ir.id) FILTER (WHERE ir.processing_status = 'ready_to_commit'::text) AS ready_to_commit_count,
    count(ir.id) FILTER (WHERE ir.processing_status = 'committed'::text) AS committed_count,
    count(ir.id) FILTER (WHERE ir.processing_status = 'duplicate'::text) AS duplicate_count,
    count(ir.id) FILTER (WHERE ir.processing_status = 'rejected'::text) AS rejected_count,
    count(ir.id) FILTER (WHERE ir.processing_status = 'failed'::text) AS failed_count
   FROM import_batches b
     JOIN data_sources ds ON ds.id = b.data_source_id
     LEFT JOIN ingestion_records ir ON ir.import_batch_id = b.id
  GROUP BY b.id, ds.name;;
create or replace view public.ingestion_review_queue with (security_invoker = true) as
 SELECT id,
    import_batch_id,
    data_source_id,
    entity_type,
    record_key,
    external_id,
    raw_payload,
    normalized_payload,
    processing_status,
    error_details,
    received_at,
    processed_at
   FROM ingestion_records ir
  WHERE processing_status = ANY (ARRAY['needs_review'::text, 'rejected'::text, 'failed'::text]);;
revoke all on public.import_batch_summary from public, anon, authenticated;
revoke all on public.ingestion_review_queue from public, anon, authenticated;
grant select on public.import_batch_summary to service_role;
grant select on public.ingestion_review_queue to service_role;
