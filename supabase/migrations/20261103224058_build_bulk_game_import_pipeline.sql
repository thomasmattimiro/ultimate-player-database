CREATE OR REPLACE FUNCTION public.stage_import_batch(p_data_source_id uuid, p_records jsonb, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
declare
  v_batch_id uuid;
  v_record jsonb;
  v_count integer := 0;
  v_key text;
  v_entity_type text;
  v_raw jsonb;
  v_normalized jsonb;
begin
  if p_data_source_id is null or not exists (
    select 1 from public.data_sources where id = p_data_source_id and is_active
  ) then
    raise exception 'An active data source is required';
  end if;
  if jsonb_typeof(p_records) <> 'array' then
    raise exception 'p_records must be a JSON array';
  end if;
  if jsonb_array_length(p_records) > 5000 then
    raise exception 'A batch cannot exceed 5000 records';
  end if;

  insert into public.import_batches (data_source_id, status, started_at, metadata)
  values (p_data_source_id, 'pending', now(), coalesce(p_metadata, '{}'::jsonb))
  returning id into v_batch_id;

  for v_record in select value from jsonb_array_elements(p_records)
  loop
    v_count := v_count + 1;
    v_key := coalesce(nullif(btrim(v_record->>'record_key'), ''), 'row-' || lpad(v_count::text, 6, '0'));
    v_entity_type := coalesce(nullif(v_record->>'entity_type',''), 'game');
    if v_entity_type not in ('player','team','event','event_division','game','season','location','stat') then
      raise exception 'Unsupported entity_type "%" in record %', v_entity_type, v_count;
    end if;
    v_raw := coalesce(v_record->'raw_payload', v_record - 'record_key' - 'entity_type' - 'normalized_payload' - 'external_id' - 'source_record_url');
    if jsonb_typeof(v_raw) <> 'object' then
      raise exception 'raw_payload must be a JSON object in record %', v_count;
    end if;
    v_normalized := v_record->'normalized_payload';

    insert into public.ingestion_records (
      import_batch_id, data_source_id, entity_type, record_key,
      external_id, source_record_url, payload_hash,
      raw_payload, normalized_payload, processing_status
    )
    values (
      v_batch_id, p_data_source_id, v_entity_type, v_key,
      nullif(v_record->>'external_id',''),
      nullif(v_record->>'source_record_url',''),
      encode(extensions.digest(v_raw::text, 'sha256'), 'hex'),
      v_raw, v_normalized,
      case when v_normalized is null or v_normalized = 'null'::jsonb then 'received' else 'normalized' end
    );
  end loop;

  update public.import_batches set records_seen = v_count where id = v_batch_id;
  return jsonb_build_object('import_batch_id',v_batch_id,'records_seen',v_count,'status','pending');
end;
$function$
;

CREATE OR REPLACE FUNCTION public.validate_game_import_batch(p_import_batch_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  r record;
  p jsonb;
  v_errors jsonb;
  v_event_id uuid;
  v_division_id uuid;
  v_team_a uuid;
  v_team_b uuid;
  v_team_a_name text;
  v_team_b_name text;
  v_date date;
  v_score_a integer;
  v_score_b integer;
  v_matches integer;
  v_status text;
  v_validated integer := 0;
  v_ready integer := 0;
  v_review integer := 0;
  v_rejected integer := 0;
  v_duplicates integer := 0;
begin
  if not exists (select 1 from public.import_batches where id = p_import_batch_id) then
    raise exception 'Import batch not found';
  end if;

  update public.import_batches set status = 'running', started_at = coalesce(started_at, now())
  where id = p_import_batch_id;

  for r in
    select * from public.ingestion_records
    where import_batch_id = p_import_batch_id
      and entity_type = 'game'
      and processing_status in ('received','normalized','needs_review','ready_to_commit')
    order by received_at, id
  loop
    v_errors := '[]'::jsonb;
    p := coalesce(r.normalized_payload, r.raw_payload);

    begin v_event_id := nullif(p->>'event_id','')::uuid; exception when others then v_event_id := null; end;
    begin v_division_id := nullif(p->>'event_division_id','')::uuid; exception when others then v_division_id := null; end;
    begin v_date := nullif(p->>'date','')::date; exception when others then v_date := null; end;
    begin
      v_score_a := nullif(p->>'score_a','')::integer;
      v_score_b := nullif(p->>'score_b','')::integer;
    exception when others then
      v_score_a := null; v_score_b := null;
    end;

    v_team_a := null;
    v_team_b := null;
    v_team_a_name := nullif(btrim(p->>'team_a_name'), '');
    v_team_b_name := nullif(btrim(p->>'team_b_name'), '');

    begin v_team_a := nullif(p->>'team_a_uuid','')::uuid; exception when others then v_team_a := null; end;
    begin v_team_b := nullif(p->>'team_b_uuid','')::uuid; exception when others then v_team_b := null; end;

    if v_event_id is null or not exists (select 1 from public.events where id = v_event_id) then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','event_id','message','A valid existing event_id is required'));
    end if;
    if v_division_id is null or not exists (select 1 from public.event_divisions where id = v_division_id and event_id = v_event_id) then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','event_division_id','message','A valid division belonging to the selected event is required'));
    end if;
    if v_date is null then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','date','message','A valid game date is required (YYYY-MM-DD)'));
    end if;
    if v_score_a is null or v_score_b is null or v_score_a < 0 or v_score_b < 0 then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','score_a/score_b','message','Both scores must be non-negative integers'));
    end if;

    if v_team_a is null and v_team_a_name is not null then
      select count(*) into v_matches
      from public.teams t
      where lower(btrim(t.name)) = lower(v_team_a_name)
        and (nullif(p->>'division','') is null or lower(btrim(t.division)) = lower(btrim(p->>'division')));
      if v_matches = 1 then
        select t.uuid into v_team_a from public.teams t
        where lower(btrim(t.name)) = lower(v_team_a_name)
          and (nullif(p->>'division','') is null or lower(btrim(t.division)) = lower(btrim(p->>'division')))
        limit 1;
      else
        v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','team_a_name','message',case when v_matches = 0 then 'Team A did not match an existing team' else 'Team A name is ambiguous; select a team explicitly' end));
      end if;
    elsif v_team_a is null then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','team_a_uuid/team_a_name','message','Team A is required'));
    elsif not exists (select 1 from public.teams where uuid = v_team_a) then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','team_a_uuid','message','Team A UUID does not exist'));
      v_team_a := null;
    end if;

    if v_team_b is null and v_team_b_name is not null then
      select count(*) into v_matches
      from public.teams t
      where lower(btrim(t.name)) = lower(v_team_b_name)
        and (nullif(p->>'division','') is null or lower(btrim(t.division)) = lower(btrim(p->>'division')));
      if v_matches = 1 then
        select t.uuid into v_team_b from public.teams t
        where lower(btrim(t.name)) = lower(v_team_b_name)
          and (nullif(p->>'division','') is null or lower(btrim(t.division)) = lower(btrim(p->>'division')))
        limit 1;
      else
        v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','team_b_name','message',case when v_matches = 0 then 'Team B did not match an existing team' else 'Team B name is ambiguous; select a team explicitly' end));
      end if;
    elsif v_team_b is null then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','team_b_uuid/team_b_name','message','Team B is required'));
    elsif not exists (select 1 from public.teams where uuid = v_team_b) then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','team_b_uuid','message','Team B UUID does not exist'));
      v_team_b := null;
    end if;

    if v_team_a is not null and v_team_b is not null and v_team_a = v_team_b then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('field','team_a/team_b','message','A team cannot play itself'));
    end if;

    if jsonb_array_length(v_errors) > 0 then
      if exists (select 1 from jsonb_array_elements(v_errors) e where e->>'field' in ('event_id','event_division_id','date','score_a/score_b')) then
        v_status := 'rejected'; v_rejected := v_rejected + 1;
      else
        v_status := 'needs_review'; v_review := v_review + 1;
      end if;
      update public.ingestion_records
      set processing_status = v_status, error_details = v_errors, processed_at = now()
      where id = r.id;
    elsif exists (
      select 1 from public.games g
      join public.game_team_results a on a.game_uuid = g.uuid and a.team_uuid = v_team_a
      join public.game_team_results b on b.game_uuid = g.uuid and b.team_uuid = v_team_b
      where g.event = v_event_id and g.event_division_id = v_division_id and g.date = v_date
    ) then
      v_duplicates := v_duplicates + 1;
      update public.ingestion_records
      set processing_status = 'duplicate',
          canonical_entity_type = 'game',
          error_details = jsonb_build_array(jsonb_build_object('message','A game with this event, division, date, and team pairing already exists')),
          processed_at = now()
      where id = r.id;
    else
      update public.ingestion_records
      set processing_status = 'ready_to_commit',
          normalized_payload = p || jsonb_build_object(
            'event_id',v_event_id,'event_division_id',v_division_id,'date',v_date,
            'team_a_uuid',v_team_a,'team_b_uuid',v_team_b,'score_a',v_score_a,'score_b',v_score_b
          ),
          error_details = '[]'::jsonb,
          processed_at = now()
      where id = r.id;
      v_ready := v_ready + 1;
    end if;
    v_validated := v_validated + 1;
  end loop;

  update public.import_batches b
  set records_seen = (select count(*) from public.ingestion_records ir where ir.import_batch_id = b.id),
      records_created = (select count(*) from public.ingestion_records ir where ir.import_batch_id = b.id and ir.processing_status = 'committed'),
      records_rejected = (select count(*) from public.ingestion_records ir where ir.import_batch_id = b.id and ir.processing_status in ('rejected','failed')),
      status = case
        when exists (select 1 from public.ingestion_records ir where ir.import_batch_id = b.id and ir.processing_status in ('received','normalized','needs_review','ready_to_commit')) then 'partial'
        when exists (select 1 from public.ingestion_records ir where ir.import_batch_id = b.id and ir.processing_status in ('rejected','failed')) then 'partial'
        else 'completed' end,
      completed_at = case when not exists (select 1 from public.ingestion_records ir where ir.import_batch_id = b.id and ir.processing_status in ('received','normalized','needs_review','ready_to_commit')) then now() else null end
  where b.id = p_import_batch_id;

  return jsonb_build_object('import_batch_id',p_import_batch_id,'validated',v_validated,'ready_to_commit',v_ready,'needs_review',v_review,'rejected',v_rejected,'duplicates',v_duplicates);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.commit_game_import_batch(p_import_batch_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  r record;
  p jsonb;
  v_game_uuid uuid;
  v_team_a uuid;
  v_team_b uuid;
  v_score_a integer;
  v_score_b integer;
  v_date date;
  v_event_id uuid;
  v_division_id uuid;
  v_team_a_name text;
  v_team_b_name text;
  v_status text;
  v_created integer := 0;
begin
  if not exists (select 1 from public.import_batches where id = p_import_batch_id) then
    raise exception 'Import batch not found';
  end if;

  for r in
    select * from public.ingestion_records
    where import_batch_id = p_import_batch_id
      and entity_type = 'game'
      and processing_status = 'ready_to_commit'
    order by (normalized_payload->>'date')::date, received_at, id
    for update
  loop
    p := r.normalized_payload;
    v_event_id := (p->>'event_id')::uuid;
    v_division_id := (p->>'event_division_id')::uuid;
    v_team_a := (p->>'team_a_uuid')::uuid;
    v_team_b := (p->>'team_b_uuid')::uuid;
    v_score_a := (p->>'score_a')::integer;
    v_score_b := (p->>'score_b')::integer;
    v_date := (p->>'date')::date;
    v_status := coalesce(nullif(p->>'status',''),'completed');
    select name into v_team_a_name from public.teams where uuid = v_team_a;
    select name into v_team_b_name from public.teams where uuid = v_team_b;

    if v_status not in ('completed','forfeit') then
      raise exception 'Only completed or forfeit games can be committed by this importer';
    end if;

    if exists (
      select 1
      from public.games g
      join public.game_team_results a on a.game_uuid = g.uuid and a.team_uuid = v_team_a
      join public.game_team_results b on b.game_uuid = g.uuid and b.team_uuid = v_team_b
      where g.event = v_event_id and g.event_division_id = v_division_id and g.date = v_date
    ) then
      update public.ingestion_records
      set processing_status = 'duplicate',
          error_details = jsonb_build_array(jsonb_build_object('message','Duplicate detected at commit; existing game preserved')),
          processed_at = now()
      where id = r.id;
      continue;
    end if;

    insert into public.games (
      date, winner, loser, winner_score, loser_score, division, event,
      event_division_id, status, data_source_id, import_batch_id,
      round_name, pool_name, scheduled_at, completed_at, location_id, venue_name
    )
    values (
      v_date,
      case when v_score_a > v_score_b then v_team_a_name when v_score_b > v_score_a then v_team_b_name else null end,
      case when v_score_a > v_score_b then v_team_b_name when v_score_b > v_score_a then v_team_a_name else null end,
      case when v_score_a > v_score_b then v_score_a when v_score_b > v_score_a then v_score_b else null end,
      case when v_score_a > v_score_b then v_score_b when v_score_b > v_score_a then v_score_a else null end,
      coalesce(nullif(p->>'division',''), (select name from public.event_divisions where id = v_division_id)),
      v_event_id,
      v_division_id,
      v_status,
      r.data_source_id,
      p_import_batch_id,
      nullif(p->>'round_name',''),
      nullif(p->>'pool_name',''),
      nullif(p->>'scheduled_at','')::timestamptz,
      coalesce(nullif(p->>'completed_at','')::timestamptz, (v_date::timestamp at time zone coalesce(nullif(p->>'timezone',''),'UTC'))),
      nullif(p->>'location_id','')::uuid,
      nullif(p->>'venue_name','')
    )
    returning uuid into v_game_uuid;

    insert into public.game_team_results (game_uuid, team_uuid, score, outcome)
    values
      (v_game_uuid, v_team_a, v_score_a, case when v_score_a > v_score_b then 'win' when v_score_a < v_score_b then 'loss' else 'tie' end),
      (v_game_uuid, v_team_b, v_score_b, case when v_score_b > v_score_a then 'win' when v_score_b < v_score_a then 'loss' else 'tie' end);

    update public.ingestion_records
    set processing_status = 'committed',
        canonical_entity_type = 'game',
        canonical_entity_uuid = v_game_uuid,
        error_details = '[]'::jsonb,
        processed_at = now()
    where id = r.id;

    v_created := v_created + 1;
  end loop;

  update public.import_batches b
  set records_seen = (select count(*) from public.ingestion_records ir where ir.import_batch_id = b.id),
      records_created = (select count(*) from public.ingestion_records ir where ir.import_batch_id = b.id and ir.processing_status = 'committed'),
      records_rejected = (select count(*) from public.ingestion_records ir where ir.import_batch_id = b.id and ir.processing_status in ('rejected','failed')),
      status = case
        when exists (select 1 from public.ingestion_records ir where ir.import_batch_id = b.id and ir.processing_status in ('received','normalized','needs_review','ready_to_commit')) then 'partial'
        when exists (select 1 from public.ingestion_records ir where ir.import_batch_id = b.id and ir.processing_status in ('rejected','failed')) then 'partial'
        else 'completed'
      end,
      completed_at = case when not exists (select 1 from public.ingestion_records ir where ir.import_batch_id = b.id and ir.processing_status in ('received','normalized','needs_review','ready_to_commit')) then now() else null end
  where b.id = p_import_batch_id;

  return jsonb_build_object(
    'import_batch_id',p_import_batch_id,
    'games_created',v_created,
    'records_created',(select records_created from public.import_batches where id = p_import_batch_id),
    'records_rejected',(select records_rejected from public.import_batches where id = p_import_batch_id),
    'status',(select status from public.import_batches where id = p_import_batch_id)
  );
end;
$function$
;
revoke all on function public.stage_import_batch(uuid,jsonb,jsonb) from public, anon, authenticated;
revoke all on function public.validate_game_import_batch(uuid) from public, anon, authenticated;
revoke all on function public.commit_game_import_batch(uuid) from public, anon, authenticated;
grant execute on function public.stage_import_batch(uuid,jsonb,jsonb) to service_role;
grant execute on function public.validate_game_import_batch(uuid) to service_role;
grant execute on function public.commit_game_import_batch(uuid) to service_role;
