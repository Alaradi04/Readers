# Readers

A Goodreads-inspired Flutter reading tracker with Supabase authentication, book discovery, reading statuses, ratings, private notes, reader profiles, and an admin catalog.

## Run

The app runs in demo mode without credentials using sample books. To connect it to Supabase, pass the project URL and publishable/anon key at launch:

```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key
```

### Google Books API key

Google Books search works without a key in some cases, but requests can be rate-limited. Enable the Books API in Google Cloud and create a key restricted to that API. Do not commit the key to the repository.

For VS Code, set `GOOGLE_BOOKS_API_KEY` in your Windows user environment variables, then restart VS Code. To avoid Flutter launching Edge, run **Terminal > Run Task > Run Readers on web-server**. This task explicitly selects Flutter's `web-server` device and passes the environment variable as a Dart define. Open the localhost URL printed in the task terminal in your browser. Alternatively, select **Readers (Google Books API key)** under **Run and Debug** and press F5.

For a terminal launch, pass the key as a Dart define:

```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key --dart-define=GOOGLE_BOOKS_API_KEY=your-google-books-key
```

Google Books requests are sent only when Search is submitted. After an HTTP 429 response, the app observes `Retry-After` when supplied, or waits 60 seconds before another request. A 429 can also mean the Google Cloud project quota has been exhausted; wait for quota reset or review the Books API quota in Google Cloud Console. Because a Flutter app is client-side, restrict the key to the Books API and to the applicable app/platform where possible.

The database should contain `profiles`, `books`, and `user_library` tables. `books.id` is the generated primary key; `books.isbn` and `books.google_books_id` are optional external identifiers, and `user_library.book_id` references `books.id`. `user_library.id` is an integer primary key; `user_notes.user_library_id` references it, so notes belong to one reader's library entry and are deleted with that entry. `profiles.id` references `auth.users.id`, and `user_library.user_id` references `profiles.id`. The library status values used by the app are `want_to_read`, `currently_reading`, and `read`. The included `supabase/schema.sql` adds external book identifiers, notes, and policies, and assumes the base tables already exist; it backfills existing notes and stops if a note cannot be matched to a library row. Authenticated users may insert books only when they include a Google Books ID or ISBN; editing and deletion remain admin-only.

To enable username sign-in, deploy the included Supabase Edge Function:

```bash
supabase functions deploy sign-in-with-username
```

## Structure

- `lib/core`: configuration and theme
- `lib/models`: database/domain models
- `lib/services`: Supabase access and demo fallback data
- `lib/features/auth`: sign in and registration
- `lib/features/home`: book search, genre filters, rating sort, and status actions
- `lib/features/library`: books grouped by reading status, ratings, and notes
- `lib/features/community`: reader search and public library viewing
- `lib/features/admin`: catalog and profile administration
- `lib/features/profile`: username, password, privacy, avatar, and logout

A new Flutter project.
