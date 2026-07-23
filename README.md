# I&QA 5S Audit — with real login and view/edit roles

This is the same 5S audit app, rebuilt with an actual backend (Supabase) so that
**who can view vs. edit is enforced by the database itself**, not just hidden in
the frontend. Even someone using the API directly (bypassing the app) can't get
around these rules.

## Roles

| Role   | Can view dashboard/log | Can submit audits | Can edit questions | Can manage user roles |
|--------|:---:|:---:|:---:|:---:|
| viewer | ✅ | ❌ | ❌ | ❌ |
| editor | ✅ | ✅ | ✅ | ❌ |
| admin  | ✅ | ✅ | ✅ | ✅ |

New sign-ups start as **viewer**. An admin upgrades people from the in-app Admin page.

## 1. Create a Supabase project (free tier is fine)

1. Go to [supabase.com](https://supabase.com) → New Project.
2. Once it's ready, open **SQL Editor** → paste in the contents of
   [`supabase/schema.sql`](./supabase/schema.sql) → Run.
   This creates the tables, seeds the default 5S questions, and sets up the
   row-level security policies that enforce the roles above.
3. Go to **Project Settings → API** and copy:
   - Project URL
   - `anon` public key

## 2. Configure the app

```bash
cp .env.example .env.local
```
Paste your Project URL and anon key into `.env.local`.

## 3. Run it locally

```bash
npm install
npm run dev
```
Open the printed local URL. Sign up for an account — you'll land as a viewer.

## 4. Make yourself an admin (one-time, manual step)

Since the very first user has no admin to promote them, do this once by hand:
1. In Supabase, go to **Table Editor → profiles**.
2. Find your row, change `role` to `admin`.
3. Reload the app — you'll now see the Admin and Manage Questions links.

From then on, use the in-app **Admin** page to promote/demote everyone else.

## 5. Put it on GitHub + deploy

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin <your-empty-github-repo-url>
git push -u origin main
```

Then, on [vercel.com](https://vercel.com) (or Netlify): "Import Project" → pick
your GitHub repo → add the same two env vars (`VITE_SUPABASE_URL`,
`VITE_SUPABASE_ANON_KEY`) in the project settings → Deploy. Every future push
to GitHub redeploys automatically.

## Notes / things worth knowing

- **This enforces real permissions.** The role checks live in Postgres row-level
  security policies (`supabase/schema.sql`), not just in the React code — so
  they hold even against direct API/database calls, not only the app's UI.
- **Auth is email/password** via Supabase's built-in auth. Supabase also
  supports Google/GitHub/Microsoft sign-in if you'd rather your team not
  manage another password — ask if you want that wired up.
- The dashboard, charts, and question-editing UI intentionally mirror the
  original single-file artifact's design and behavior, so it should feel
  familiar.
- Not yet ported from the original artifact: the before/after photo upload and
  the per-question remarks/action/responsible/status detail fields (only a
  simple remarks box is included here). Both can be added the same way the
  rest of this was built — happy to extend this further if useful.
