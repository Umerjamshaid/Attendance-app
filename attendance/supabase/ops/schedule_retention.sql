-- Requires pg_cron, pg_net and the two Vault secrets documented in backend-setup.
-- The job text contains no credential values or organization-specific identifiers.
select cron.schedule('workcheck-evidence-retention', '15 * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='workcheck_functions_url') || '/retention-cleanup',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='workcheck_cron_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
$$);
