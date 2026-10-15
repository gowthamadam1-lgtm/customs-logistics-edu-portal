# Customs and Logistics Edu Portal

A learning portal for customs and logistics: learners work through courses
and topics, take quizzes, earn points on a leaderboard, and raise support
tickets. Admins manage courses, topics, questions, learners and tickets.

## How it is built

| Part | Where |
| --- | --- |
| Website (HTML, CSS and JavaScript in one file) | `index.html` |
| Database, login and file storage | [Supabase](https://supabase.com) |
| Server-side quiz grading | `supabase/functions/submit-quiz/` |
| Database changes | `supabase/migrations/` |

The Supabase URL and the **publishable** key in `index.html` are meant to be
public. Never put a secret / service-role key in `index.html` or commit it to
this repository — the database rules (row-level security and column
privileges) are what keep data safe.

## Running it locally

Open `index.html` in a browser, or serve the folder:

```bash
python3 -m http.server 8000
# then visit http://localhost:8000
```

## Deploying server changes

```bash
supabase functions deploy submit-quiz
supabase db push        # applies files in supabase/migrations/
```

Deploy the function before applying the migration.
