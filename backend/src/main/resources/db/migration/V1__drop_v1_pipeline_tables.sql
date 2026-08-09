-- V1: retire the v1 (pipeline-created) tables.
--
-- Per ADR 0006, migration strategy is RECREATE + RE-BACKFILL, not ALTER:
-- everything in these tables is re-derivable from Garmin + raw JSONB.
-- !! Destructive by design. Run only when ready to re-backfill (pipeline v2). !!

DROP TABLE IF EXISTS activity_splits CASCADE;
DROP TABLE IF EXISTS activity_hr_zones CASCADE;
DROP TABLE IF EXISTS activities CASCADE;
