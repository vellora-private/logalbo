-- Run in Supabase SQL Editor. Create auth users first in Authentication > Users.
create extension if not exists pgcrypto;
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,username text unique not null,display_name text not null,role text not null default 'worker' check(role in ('manager','worker')),active boolean not null default true,created_at timestamptz default now());
create table if not exists public.clients(id uuid primary key default gen_random_uuid(),name text not null,phone text,email text,address text,notes text,created_at timestamptz default now());
create table if not exists public.jobs(id uuid primary key default gen_random_uuid(),title text not null,job_type text not null check(job_type in ('removal','outreach')),status text not null default 'scheduled' check(status in ('scheduled','in_progress','completed','cancelled')),job_date date not null,start_time time not null,end_time time,client_id uuid references public.clients(id) on delete set null,location text,description text,quoted_price numeric(10,2),created_at timestamptz default now());
create table if not exists public.job_assignments(job_id uuid not null references public.jobs(id) on delete cascade,worker_id uuid not null references public.profiles(id) on delete cascade,primary key(job_id,worker_id));
create or replace function public.is_manager() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=(select auth.uid()) and role='manager' and active=true) $$;
create or replace function public.is_active_worker() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=(select auth.uid()) and active=true) $$;
create or replace function public.assigned_to(j uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.job_assignments where job_id=j and worker_id=(select auth.uid())) $$;
alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.jobs enable row level security;
alter table public.job_assignments enable row level security;
create policy "active team sees profiles" on public.profiles for select to authenticated using(public.is_active_worker());
create policy "manager manages profiles" on public.profiles for all to authenticated using(public.is_manager()) with check(public.is_manager());
create policy "manager manages clients" on public.clients for all to authenticated using(public.is_manager()) with check(public.is_manager());
create policy "team reads allowed jobs" on public.jobs for select to authenticated using(public.is_manager() or (public.is_active_worker() and public.assigned_to(id)));
create policy "manager inserts jobs" on public.jobs for insert to authenticated with check(public.is_manager());
create policy "manager updates jobs" on public.jobs for update to authenticated using(public.is_manager()) with check(public.is_manager());
create policy "manager deletes jobs" on public.jobs for delete to authenticated using(public.is_manager());
create policy "worker updates assigned jobs" on public.jobs for update to authenticated using(public.is_active_worker() and public.assigned_to(id)) with check(public.is_active_worker() and public.assigned_to(id));
create policy "team reads assignments" on public.job_assignments for select to authenticated using(public.is_manager() or (public.is_active_worker() and worker_id=(select auth.uid())));
create policy "manager inserts assignments" on public.job_assignments for insert to authenticated with check(public.is_manager());
create policy "manager deletes assignments" on public.job_assignments for delete to authenticated using(public.is_manager());
-- Workers may update only status. Protect every other field even if RLS permits UPDATE.
create or replace function public.guard_worker_job_update() returns trigger language plpgsql security definer set search_path=public as $$ begin
if not public.is_manager() then
 if new.id is distinct from old.id or new.title is distinct from old.title or new.job_type is distinct from old.job_type or new.job_date is distinct from old.job_date or new.start_time is distinct from old.start_time or new.end_time is distinct from old.end_time or new.client_id is distinct from old.client_id or new.location is distinct from old.location or new.description is distinct from old.description or new.quoted_price is distinct from old.quoted_price or new.created_at is distinct from old.created_at then raise exception 'Workers may only change job status'; end if;
 if new.status not in ('in_progress','completed') or (old.status='scheduled' and new.status <> 'in_progress') or (old.status='in_progress' and new.status <> 'completed') or old.status in ('completed','cancelled') then raise exception 'Invalid worker status transition'; end if;
end if;return new;end $$;
drop trigger if exists guard_worker_job_update on public.jobs;
create trigger guard_worker_job_update before update on public.jobs for each row execute function public.guard_worker_job_update();
-- Realtime publication for schedule changes. App uses manual Sync button for refresh.
-- IMPORTANT: Create the first manager profile manually using the manager's auth user UUID.
-- insert into public.profiles(id,username,display_name,role) values ('YOUR_MANAGER_AUTH_UUID','admin','Anthony','manager');
-- insert into public.profiles(id,username,display_name,role) values ('YOUR_LJ_AUTH_UUID','LJ','LJ','worker');
