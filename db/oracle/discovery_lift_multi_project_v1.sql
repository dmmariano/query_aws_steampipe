-- Oracle Discovery/Lift multi-project physical contract v1
--
-- Status: DDL PACKAGE ONLY. Do not run without explicit DBA/RM approval.
--
-- Scope:
-- - Creates CA_DISC_LIFT_* objects in the connected schema.
-- - Does not create users, schemas, grants, jobs, triggers, or customer data.
-- - Does not touch Knowledge/RAG objects.
--
-- Required preflight before execution:
-- - ADB connectivity check returns OK.
-- - Target objects do not already exist.
-- - Connected user is the DBA-approved Discovery/Lift owner.
-- - Rollback script is available.

set define off

create table CA_DISC_LIFT_PROJECTS (
  client_id varchar2(128) not null,
  provider varchar2(64) not null,
  environment varchar2(64) default 'default' not null,
  project_id varchar2(128) not null,
  project_label varchar2(160) not null,
  active char(1) default 'Y' not null check (active in ('Y','N')),
  eligible_for_workplan char(1) default 'Y' not null check (eligible_for_workplan in ('Y','N')),
  blocked_reason_code varchar2(80),
  last_projection_cursor varchar2(256),
  created_at timestamp default systimestamp not null,
  updated_at timestamp default systimestamp not null,
  constraint CA_DISC_LIFT_PROJECTS_PK primary key (
    client_id,
    provider,
    environment,
    project_id
  )
);

create table CA_DISC_LIFT_RUNS (
  run_id varchar2(128) not null,
  idempotency_key varchar2(128) not null,
  client_id varchar2(128) not null,
  provider varchar2(64) not null,
  environment varchar2(64) default 'default' not null,
  project_ids_json clob not null check (project_ids_json is json),
  project_count number(10) not null check (project_count >= 1),
  source_snapshot_ref varchar2(256),
  status varchar2(40) not null,
  approval_required char(1) default 'N' not null check (approval_required in ('Y','N')),
  approval_status varchar2(40) default 'NOT_REQUIRED' not null,
  approval_ref varchar2(256),
  approval_reason_code varchar2(80),
  created_at timestamp default systimestamp not null,
  updated_at timestamp default systimestamp not null,
  rollback_run_marker varchar2(256),
  constraint CA_DISC_LIFT_RUNS_PK primary key (run_id),
  constraint CA_DISC_LIFT_RUNS_IDEMP_UQ unique (idempotency_key),
  constraint CA_DISC_LIFT_RUNS_STATUS_CK check (
    status in (
      'VALIDATING',
      'REJECTED',
      'QUEUED',
      'RUNNING',
      'PARTIAL_RETRYABLE',
      'READY',
      'EMPTY',
      'FAILED_RETRYABLE',
      'FAILED_FINAL',
      'CANCELLED',
      'ROLLED_BACK'
    )
  ),
  constraint CA_DISC_LIFT_RUNS_APPROVAL_CK check (
    approval_status in ('NOT_REQUIRED','PENDING','APPROVED','REJECTED')
  )
);

create table CA_DISC_LIFT_JOURNAL (
  run_id varchar2(128) not null,
  event_id varchar2(128) not null,
  event_sequence number(20) not null check (event_sequence >= 0),
  event_type varchar2(80) not null,
  event_status varchar2(20) not null,
  client_id varchar2(128) not null,
  provider varchar2(64) not null,
  environment varchar2(64) default 'default' not null,
  project_ids_digest varchar2(128) not null,
  project_id_ref varchar2(256),
  batch_id varchar2(128),
  observed_at timestamp default systimestamp not null,
  committed_at timestamp,
  projection_cursor varchar2(256) not null,
  retry_after_ms number(12),
  event_payload_json clob check (event_payload_json is json),
  constraint CA_DISC_LIFT_JOURNAL_PK primary key (run_id, event_sequence),
  constraint CA_DISC_LIFT_JOURNAL_EVENT_UQ unique (event_id),
  constraint CA_DISC_LIFT_JOURNAL_RUN_FK foreign key (run_id)
    references CA_DISC_LIFT_RUNS(run_id),
  constraint CA_DISC_LIFT_JOURNAL_TYPE_CK check (
    event_type in (
      'REQUEST_ACCEPTED',
      'PROJECT_SET_VALIDATED',
      'RUN_QUEUED',
      'RUN_STARTED',
      'PROJECT_PROGRESS',
      'ARTIFACTS_PUBLISHED',
      'APPROVAL_REQUIRED',
      'APPROVAL_RECORDED',
      'RUN_READY',
      'RUN_FAILED',
      'RUN_CANCELLED',
      'RUN_ROLLED_BACK'
    )
  ),
  constraint CA_DISC_LIFT_JOURNAL_STATUS_CK check (
    event_status in ('INFO','READY','PENDING','WARNING','ERROR')
  )
);

create table CA_DISC_LIFT_ARTIFACTS (
  run_id varchar2(128) not null,
  artifact_type varchar2(40) not null,
  artifact_ref varchar2(256) not null,
  artifact_status varchar2(40) default 'PUBLISHED' not null,
  metadata_json clob check (metadata_json is json),
  created_at timestamp default systimestamp not null,
  constraint CA_DISC_LIFT_ARTIFACTS_PK primary key (run_id, artifact_type),
  constraint CA_DISC_LIFT_ARTIFACTS_RUN_FK foreign key (run_id)
    references CA_DISC_LIFT_RUNS(run_id),
  constraint CA_DISC_LIFT_ARTIFACTS_TYPE_CK check (
    artifact_type in ('WORKLOAD_BUILDER','WORKPLAN','MANIFEST')
  )
);

create index CA_DISC_LIFT_PROJECTS_SCOPE_IX
  on CA_DISC_LIFT_PROJECTS (
    client_id,
    provider,
    environment,
    active,
    eligible_for_workplan
  );

create index CA_DISC_LIFT_RUNS_SCOPE_IX
  on CA_DISC_LIFT_RUNS (
    client_id,
    provider,
    environment,
    status,
    updated_at
  );

create index CA_DISC_LIFT_JOURNAL_CURSOR_IX
  on CA_DISC_LIFT_JOURNAL (
    run_id,
    projection_cursor
  );

create or replace package CA_DISC_LIFT_API as
  procedure register_run(
    p_run_id in varchar2,
    p_idempotency_key in varchar2,
    p_client_id in varchar2,
    p_provider in varchar2,
    p_environment in varchar2,
    p_project_ids_json in clob,
    p_project_count in number,
    p_source_snapshot_ref in varchar2 default null,
    p_approval_required in char default 'N',
    p_approval_ref in varchar2 default null
  );

  procedure append_event(
    p_run_id in varchar2,
    p_event_id in varchar2,
    p_event_sequence in number,
    p_event_type in varchar2,
    p_event_status in varchar2,
    p_client_id in varchar2,
    p_provider in varchar2,
    p_environment in varchar2,
    p_project_ids_digest in varchar2,
    p_projection_cursor in varchar2,
    p_project_id_ref in varchar2 default null,
    p_batch_id in varchar2 default null,
    p_retry_after_ms in number default null,
    p_event_payload_json in clob default null
  );

  procedure publish_artifact(
    p_run_id in varchar2,
    p_artifact_type in varchar2,
    p_artifact_ref in varchar2,
    p_metadata_json in clob default null
  );

  procedure set_run_status(
    p_run_id in varchar2,
    p_status in varchar2,
    p_rollback_run_marker in varchar2 default null
  );
end CA_DISC_LIFT_API;
/

create or replace package body CA_DISC_LIFT_API as
  procedure register_run(
    p_run_id in varchar2,
    p_idempotency_key in varchar2,
    p_client_id in varchar2,
    p_provider in varchar2,
    p_environment in varchar2,
    p_project_ids_json in clob,
    p_project_count in number,
    p_source_snapshot_ref in varchar2 default null,
    p_approval_required in char default 'N',
    p_approval_ref in varchar2 default null
  ) as
  begin
    if p_client_id is null or p_provider is null or p_project_count < 1 then
      raise_application_error(-20000, 'INVALID_SCOPE');
    end if;

    insert into CA_DISC_LIFT_RUNS (
      run_id,
      idempotency_key,
      client_id,
      provider,
      environment,
      project_ids_json,
      project_count,
      source_snapshot_ref,
      status,
      approval_required,
      approval_status,
      approval_ref
    ) values (
      p_run_id,
      p_idempotency_key,
      p_client_id,
      p_provider,
      nvl(p_environment, 'default'),
      p_project_ids_json,
      p_project_count,
      p_source_snapshot_ref,
      'QUEUED',
      nvl(p_approval_required, 'N'),
      case
        when nvl(p_approval_required, 'N') = 'Y' then 'PENDING'
        else 'NOT_REQUIRED'
      end,
      p_approval_ref
    );
  exception
    when dup_val_on_index then
      null;
  end register_run;

  procedure append_event(
    p_run_id in varchar2,
    p_event_id in varchar2,
    p_event_sequence in number,
    p_event_type in varchar2,
    p_event_status in varchar2,
    p_client_id in varchar2,
    p_provider in varchar2,
    p_environment in varchar2,
    p_project_ids_digest in varchar2,
    p_projection_cursor in varchar2,
    p_project_id_ref in varchar2 default null,
    p_batch_id in varchar2 default null,
    p_retry_after_ms in number default null,
    p_event_payload_json in clob default null
  ) as
  begin
    insert into CA_DISC_LIFT_JOURNAL (
      run_id,
      event_id,
      event_sequence,
      event_type,
      event_status,
      client_id,
      provider,
      environment,
      project_ids_digest,
      project_id_ref,
      batch_id,
      committed_at,
      projection_cursor,
      retry_after_ms,
      event_payload_json
    ) values (
      p_run_id,
      p_event_id,
      p_event_sequence,
      p_event_type,
      p_event_status,
      p_client_id,
      p_provider,
      nvl(p_environment, 'default'),
      p_project_ids_digest,
      p_project_id_ref,
      p_batch_id,
      systimestamp,
      p_projection_cursor,
      p_retry_after_ms,
      p_event_payload_json
    );
  end append_event;

  procedure publish_artifact(
    p_run_id in varchar2,
    p_artifact_type in varchar2,
    p_artifact_ref in varchar2,
    p_metadata_json in clob default null
  ) as
  begin
    merge into CA_DISC_LIFT_ARTIFACTS a
    using (
      select p_run_id run_id, p_artifact_type artifact_type from dual
    ) s
    on (a.run_id = s.run_id and a.artifact_type = s.artifact_type)
    when matched then update set
      artifact_ref = p_artifact_ref,
      metadata_json = p_metadata_json,
      created_at = systimestamp
    when not matched then insert (
      run_id,
      artifact_type,
      artifact_ref,
      metadata_json
    ) values (
      p_run_id,
      p_artifact_type,
      p_artifact_ref,
      p_metadata_json
    );
  end publish_artifact;

  procedure set_run_status(
    p_run_id in varchar2,
    p_status in varchar2,
    p_rollback_run_marker in varchar2 default null
  ) as
  begin
    update CA_DISC_LIFT_RUNS
    set status = p_status,
        rollback_run_marker = nvl(p_rollback_run_marker, rollback_run_marker),
        updated_at = systimestamp
    where run_id = p_run_id;

    if sql%rowcount = 0 then
      raise_application_error(-20001, 'RUN_NOT_FOUND');
    end if;
  end set_run_status;
end CA_DISC_LIFT_API;
/
