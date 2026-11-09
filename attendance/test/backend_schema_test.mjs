// Runs the actual migration against an isolated PostgreSQL WASM database.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { join } from 'node:path';

const require = createRequire(import.meta.url);
const { PGlite } = require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth; create schema storage;
  grant usage on schema public,auth,storage to anon,authenticated,service_role;
  create table auth.users(id uuid primary key, email text);
  create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
  create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
  create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text,created_at timestamptz default now());
  create function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name,'/') $$;
  alter table storage.objects enable row level security;
  grant select,insert,delete on storage.objects to authenticated;
  grant all on storage.objects to service_role;
`);
for (const file of (await readdir(new URL('../supabase/migrations/', import.meta.url))).filter((name) => name.endsWith('.sql')).sort()) {
  await db.exec(await readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8'));
}
const buckets = (await db.query('select id, public, file_size_limit, allowed_mime_types from storage.buckets order by id')).rows;
assert.deepEqual(buckets, [
  { id: 'attendance-evidence', public: false, file_size_limit: 2097152, allowed_mime_types: ['image/jpeg', 'image/png'] },
  { id: 'profile-media', public: false, file_size_limit: 2097152, allowed_mime_types: ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'] },
]);
const company = '10000000-0000-4000-8000-000000000001';
const otherCompany = '10000000-0000-4000-8000-000000000002';
const admin = '20000000-0000-4000-8000-000000000001';
const employee = '20000000-0000-4000-8000-000000000002';
const other = '20000000-0000-4000-8000-000000000003';
const request = '30000000-0000-4000-8000-000000000001';
const installation = '40000000-0000-4000-8000-000000000001';
await db.exec(`
  insert into public.organizations(id,name,window_mode) values ('${company}','Company A','always'),('${otherCompany}','Company B','always');
  insert into auth.users values ('${admin}','admin@example.invalid'),('${employee}','employee@example.invalid'),('${other}','other@example.invalid');
  insert into public.memberships(user_id,organization_id,employee_code,role) values ('${admin}','${company}','ADMIN','admin'),('${employee}','${company}','EMP001','employee'),('${other}','${otherCompany}','EMP001','admin');
  insert into public.profiles(user_id,name) values ('${admin}','Admin'),('${employee}','Employee'),('${other}','Other');
  insert into storage.objects(bucket_id,name) values ('attendance-evidence','${company}/${employee}/${request}');
`);
/** Switches the isolated database's SQL role and simulated authenticated user. */
async function role(name, user) {
  await db.exec('reset role');
  await db.query(`select set_config('request.jwt.claim.sub',$1,false)`, [user || '']);
  await db.exec(`set role ${name}`);
}
/** Reads the scalar assertion value from a test query. */
async function value(sql) { return (await db.query(sql)).rows[0].value; }
async function denied(sql) { await assert.rejects(db.exec(sql)); }
await role('anon');
await denied('select * from public.check_ins');
await denied('select public.current_employee()');

await role('service_role');
assert.equal(await value(`select public.claim_submission('${employee}','${request}') as value`), true);
assert.equal(await value(`select public.claim_submission('${employee}','${request}') as value`), false);
const finalize = `select public.finalize_check_in('${employee}','${request}',now(),'Test device','${company}/${employee}/${request}',24.8,67.0,20,'${installation}','android') as value`;
const record = await value(finalize);
assert.equal((await value(finalize)).id, record.id, 'same request is idempotent');
assert.equal(await value('select count(*)::int as value from public.check_ins'), 1);

await role('authenticated', employee);
assert.equal(await value('select count(*)::int as value from public.check_ins'), 1);
assert.equal(await value('select count(*)::int as value from public.attendance_evidence'), 0, 'employees cannot read GPS');
assert.equal(await value("select count(*)::int as value from storage.objects where bucket_id='attendance-evidence'"), 0, 'employees cannot read photo objects');
assert.equal(await value('select count(*)::int as value from public.profiles'), 1);
assert.equal((await value('select public.current_employee() as value')).id, 'EMP001');
assert.equal((await db.query('select * from public.company_employees()')).rows.length, 0);
await denied("update public.memberships set role='admin'");
await denied(`select public.set_employee_active('${employee}','ADMIN',false)`);
await denied("insert into public.check_ins(organization_id) values (gen_random_uuid())");
await denied("select public.save_attendance_policy('always',7,13)");
await denied(`select public.claim_submission('${employee}','${request}')`);
await db.exec("update public.profiles set name='Updated' where user_id=auth.uid()");
assert.equal((await value('select public.current_employee() as value')).name, 'Updated');
await denied(`update public.profiles set avatar_path='${admin}/avatar-stolen.jpg' where user_id=auth.uid()`);

await role('authenticated', other);
assert.equal(await value('select count(*)::int as value from public.check_ins'), 0);
assert.equal(await value('select count(*)::int as value from public.attendance_evidence'), 0);
assert.equal(await value('select count(*)::int as value from public.organizations'), 1);

await role('authenticated', admin);
assert.equal(await value('select count(*)::int as value from public.check_ins'), 1);
assert.equal(await value('select count(*)::int as value from public.attendance_evidence'), 1);
await db.exec("select public.save_attendance_policy('period',7,13)");
await denied("select public.save_attendance_policy('period',13,7)");
await role('service_role');
await denied(`select public.set_employee_active('${admin}','ADMIN',false)`);
await db.exec(`select public.set_employee_active('${admin}','EMP001',false)`);
await role('authenticated', employee);
assert.equal(await value('select count(*)::int as value from public.check_ins'), 0, 'deactivation immediately restricts old JWTs');
assert.equal(await value('select public.current_employee() as value'), null);
await role('service_role');
await db.exec(`select public.set_employee_active('${admin}','EMP001',true)`);

await role('postgres');
const oldPhoto = `${company}/${employee}/orphan`;
await db.exec(`insert into storage.objects(bucket_id,name,created_at) values ('attendance-evidence','${oldPhoto}',now()-interval '2 days'); update public.attendance_evidence set expires_at=now()-interval '1 day';`);
await role('service_role');
const orphans = (await db.query('select * from public.orphaned_media()')).rows;
assert.equal(orphans.length, 1);
assert.equal(orphans[0].name, oldPhoto, 'cleanup never treats committed evidence as an orphan');
await role('authenticated', admin);
assert.equal(await value('select count(*)::int as value from public.attendance_evidence'), 0, 'expired evidence cannot be read before the cleanup job runs');
await db.close();
console.log('PASS: migration, RLS, tenant isolation, idempotency, deactivation, last-admin protection, and evidence expiry');
