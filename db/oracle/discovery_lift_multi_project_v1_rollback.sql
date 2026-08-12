-- Rollback for Oracle Discovery/Lift multi-project physical contract v1.
--
-- Drops only CA_DISC_LIFT_* objects created by
-- discovery_lift_multi_project_v1.sql.
--
-- Do not run if these objects have been promoted to a live integration without
-- a separate data retention decision. This rollback is intended before real
-- data operations are authorized.

set define off

drop package CA_DISC_LIFT_API;

drop table CA_DISC_LIFT_ARTIFACTS purge;

drop table CA_DISC_LIFT_JOURNAL purge;

drop table CA_DISC_LIFT_RUNS purge;

drop table CA_DISC_LIFT_PROJECTS purge;
