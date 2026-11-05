# Logalbo Junk and Hauling — setup

## 1. Supabase
Create a Supabase project. In SQL Editor, run `supabase.sql` once. In Project Settings > API (or Connect), copy the **Project URL** and **publishable/anon key** into the two constants at the top of the JavaScript near the bottom of `index.html`. **Never** paste a service_role or secret key into this HTML.

## 2. Create manager and LJ
In Supabase > Authentication > Users, use **Add user** to create two users (with auto-confirm enabled):

- Manager: `admin@crew.logalbo.invalid`, password: **choose your own strong password**.
- LJ: `lj@crew.logalbo.invalid`, password: `LJ123456` (temporary; replace with a stronger unique password as soon as possible).

The app accepts usernames `admin` and `LJ`, converting them internally to those email aliases. These `.invalid` addresses are deliberately not deliverable, so email password recovery will not work; reset passwords from the Supabase dashboard or switch to real email addresses and update the username mapping. Supabase Auth requires at least 6 characters by default, so password `LJ` is not supported securely by this approach.

Copy both auth user UUIDs from Authentication > Users, then run in SQL Editor, substituting the UUIDs:

```sql
insert into public.profiles(id,username,display_name,role)
values ('MANAGER_AUTH_UUID','admin','Anthony','manager');
insert into public.profiles(id,username,display_name,role)
values ('LJ_AUTH_UUID','LJ','LJ','worker');
```

To add workers later: create an auth user with `username@crew.logalbo.invalid` and a strong password, then insert the matching `profiles` row with `role='worker'`. Only trusted managers should be allowed access to the Supabase dashboard. Workers cannot grant themselves manager access. Disable public signups under Authentication settings if you only create staff accounts manually.

## 3. Logo
The supplied Facebook CDN URL may expire. Download the image you own from Facebook and save it beside `index.html` as `logo.jpg` to show the real logo reliably. Until then the app shows the generated icon.

## 4. Deploy and install
Upload all files in this folder to a **GitHub Pages repository root**. Set Settings > Pages > Deploy from branch > main/root. Open the HTTPS website on mobile and use Add to Home Screen (iPhone Safari) or Install App (Android Chrome).

## What works
Manager can create/edit/delete jobs, assign multiple employees, save clients, and see the full calendar. Workers see only their assigned jobs and can move jobs from scheduled → in progress → completed. A Sync button reloads data from Supabase. This is a network-first PWA; offline access is limited to the app shell, and jobs need a connection to load or save.

## Notes
The app uses Supabase row-level security. Worker profiles are visible to other active staff for display names, so don't put sensitive information in profile fields. The project is a functional starter, not a complete payroll/timeclock system. Before real deployment, test both roles and change all temporary passwords.


## Username-only sign-in update
Sign in using `Anthony` or `LJ` and the password you created in Supabase Authentication. The app maps these usernames to the existing authentication emails internally. Supabase still authenticates by email under the hood. To add more employees, create their auth user and profile, then update `LOGIN_EMAILS` in `index.html`. This mapping is visible in public website source; do not treat employee email addresses as secret. Never put passwords in the app source. For a scalable private username directory, implement a rate-limited server-side lookup or dedicated authentication service.


## Full mobile redesign
This release replaces the prior UI entirely with a mobile-first associate home screen, quick actions, calendar date picker, assignment feed, team and account screens. Supabase schema and existing logins are unchanged. Replace ALL GitHub Pages files and hard-refresh. The browser app uses the existing username mapping for Anthony and LJ. To add new usernames, update LOGIN_EMAILS in index.html; for production, migrate this lookup to a secure server endpoint.
