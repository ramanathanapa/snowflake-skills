-- Readiness scorecard: summarizes the phase checks run earlier in THIS session (platform_checks is a temporary table).
-- To score everything at once, run all phase scripts and this file in one session, for example:
--   cat checks/0*.sql checks/1*.sql checks/99-scorecard.sql > all-checks.sql   (then run all-checks.sql)
SELECT phase,
       COUNT_IF(status = 'PASS') AS pass, COUNT_IF(status = 'WARN') AS warn, COUNT_IF(status = 'FAIL') AS fail, COUNT_IF(status = 'INFO') AS info,
       COALESCE(LISTAGG(IFF(status IN ('FAIL', 'WARN'), check_id, NULL), ', ') WITHIN GROUP (ORDER BY check_id), '') AS open_items
FROM platform_checks
GROUP BY phase
ORDER BY phase;
