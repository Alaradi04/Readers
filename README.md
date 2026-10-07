# Readers

Readers is a Flutter reading tracker for discovering books, tracking reading progress, and connecting with other readers. It includes Supabase authentication and an optional Google Books search integration.

## Features

- Discover and search for books
- Track books as **Want to read**, **Currently reading**, or **Read**
- Rate books and keep private notes
- Create a reader profile and browse public reader libraries
- Administer the book catalog
- Includes sample books for demonstration

## Getting started

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install), then run:

```bash
flutter pub get
flutter run
```

To connect the app to your own Supabase project, provide its project URL and publishable key as Dart defines:

```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-publishable-key
```

The Supabase database must have the base tables expected by the app. Review `supabase/schema.sql` before applying it; it adds book identifiers, notes, and access policies to an existing schema. Username sign-in also requires the Supabase CLI and deployment of the included Edge Function:

```bash
supabase functions deploy sign-in-with-username
```

## Google Books search (optional)

Google Books search can work without an API key, but may be rate-limited. To use a key, enable the Books API in Google Cloud and provide `GOOGLE_BOOKS_API_KEY` when launching the app:

```bash
flutter run --dart-define=GOOGLE_BOOKS_API_KEY=your-google-books-api-key
```

You can combine this define with the Supabase defines above. Because values supplied to a Flutter client app can be extracted from the app, do not treat API keys as secrets. Restrict a Google Books key to the Books API and applicable platforms, monitor its quota, and never commit a real key to the repository.

## Security

The Supabase publishable (anon) key is intended for client-side use; access to data must be protected with correctly configured Row Level Security policies. **Never put a Supabase service-role key or other privileged secret in the app or repository.**
