# Readers

A Goodreads-inspired Flutter reading tracker with Supabase authentication, book discovery, reading statuses, ratings, and profile management.

## Run

The app runs in demo mode without credentials using sample books. To connect it to Supabase, pass the project URL and publishable/anon key at launch:

```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key
```

The database should contain `profiles`, `books`, and `user_library` tables. `profiles.id` references `auth.users.id`; `user_library.user_id` references `profiles.id`; and `user_library.book_id` references `books.id`. The library status values used by the app are `want_to_read`, `currently_reading`, and `read`.

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
- `lib/features/library`: books grouped by reading status and ratings for read books
- `lib/features/profile`: username, password, and logout

A new Flutter project.
