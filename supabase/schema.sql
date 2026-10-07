-- Run this script in the Supabase SQL Editor.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', 'Reader'),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.books enable row level security;
alter table public.user_library enable row level security;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'Privacy'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'privacy'
  ) then
    alter table public.profiles rename column "Privacy" to privacy;
  end if;
end $$;

alter table public.profiles add column if not exists privacy text;
update public.profiles
set privacy = case
  when lower(trim(coalesce(privacy, ''))) = 'public' then 'public'
  else 'private'
end;
alter table public.profiles alter column privacy set default 'private';
alter table public.profiles alter column privacy set not null;

revoke select on public.profiles from public, anon, authenticated;
grant select (id, username, role, picture, privacy)
  on public.profiles to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_privacy_check'
  ) then
    alter table public.profiles
      add constraint profiles_privacy_check
      check (privacy in ('public', 'private'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'books'
      and column_name = 'id'
  ) then
    raise exception 'Expected public.books.id primary key';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'books'
      and column_name = 'ISBN'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'books'
      and column_name = 'isbn'
  ) then
    alter table public.books rename column "ISBN" to isbn;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'books'
      and column_name = 'isbn'
      and is_identity = 'YES'
  ) then
    alter table public.books alter column isbn drop identity if exists;
  end if;
end;
$$;

alter table public.books add column if not exists isbn text;
alter table public.books add column if not exists google_books_id text;
alter table public.books
  alter column isbn type text using isbn::text;

create unique index if not exists books_isbn_unique
  on public.books (lower(btrim(isbn)))
  where isbn is not null and btrim(isbn) <> '';
create unique index if not exists books_google_books_id_unique
  on public.books (google_books_id)
  where google_books_id is not null and btrim(google_books_id) <> '';

do $$
declare
  books_id_type text;
  library_book_type text;
  foreign_key record;
  foreign_key_definitions text[] := array[]::text[];
  foreign_key_definition text;
  unmatched_book_ids boolean;
begin
  select data_type into books_id_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'books'
    and column_name = 'id';

  select data_type into library_book_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'user_library'
    and column_name = 'book_id';

  if books_id_type not in ('smallint', 'integer', 'bigint') then
    raise exception 'public.books.id must be an integer type';
  end if;

  if library_book_type is distinct from books_id_type then
    drop trigger if exists refresh_book_rate on public.user_library;

    if to_regclass('public.user_notes') is not null
      and exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'user_notes'
          and column_name = 'user_id'
      ) and exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'user_notes'
          and column_name = 'book_id'
      ) then
      alter table public.user_notes
        add column if not exists user_library_id bigint;

      update public.user_notes as notes
      set user_library_id = library.id
      from public.user_library as library
      where library.user_id = notes.user_id
        and library.book_id::text = notes.book_id::text
        and notes.user_library_id is null;

      for foreign_key in
        select conname
        from pg_constraint
        where conrelid = 'public.user_notes'::regclass
          and confrelid = 'public.user_library'::regclass
          and contype = 'f'
      loop
        execute format(
          'alter table public.user_notes drop constraint %I',
          foreign_key.conname
        );
      end loop;
    end if;

    for foreign_key in
      select oid, conname
      from pg_constraint
      where conrelid = 'public.user_library'::regclass
        and confrelid = 'public.books'::regclass
        and contype = 'f'
    loop
      foreign_key_definition := pg_get_constraintdef(foreign_key.oid);
      foreign_key_definition := regexp_replace(
        foreign_key_definition,
        $pattern$REFERENCES [^ ]+[[:space:]]*\([^)]*\)$pattern$,
        'REFERENCES public.books (id)'
      );
      foreign_key_definitions := array_append(
        foreign_key_definitions,
        format('%I %s', foreign_key.conname, foreign_key_definition)
      );
      execute format(
        'alter table public.user_library drop constraint %I',
        foreign_key.conname
      );
    end loop;

    if library_book_type in ('text', 'character varying', 'character') then
      update public.user_library as library
      set book_id = books.id::text
      from public.books as books
      where library.book_id::text = books.isbn;

      if exists (
        select 1 from public.user_library
        where book_id::text !~ '^[0-9]+$'
      ) then
        raise exception 'Cannot convert user_library.book_id: some values are not numeric book IDs or matching ISBNs';
      end if;
    end if;

    execute format(
      'alter table public.user_library alter column book_id type %I using book_id::%I',
      books_id_type,
      books_id_type
    );

    foreach foreign_key_definition in array foreign_key_definitions
    loop
      execute format(
        'alter table public.user_library add constraint %s',
        foreign_key_definition
      );
    end loop;
  end if;

  if not exists (
    select 1
    from pg_constraint as constraint_row
    join pg_attribute as column_row
      on column_row.attrelid = constraint_row.conrelid
      and column_row.attname = 'book_id'
    where constraint_row.conrelid = 'public.user_library'::regclass
      and constraint_row.confrelid = 'public.books'::regclass
      and constraint_row.contype = 'f'
      and constraint_row.conkey = array[column_row.attnum]::smallint[]
  ) then
    alter table public.user_library
      add constraint user_library_book_id_fkey
      foreign key (book_id) references public.books (id);
  end if;
end;
$$;

alter table public.books
  alter column rate type numeric(3,1)
  using rate::numeric;

alter table public.books
  alter column rate type numeric(3,1)
  using rate::numeric;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.user_library'::regclass
      and conname = 'user_library_user_book_unique'
  ) then
    alter table public.user_library
      add constraint user_library_user_book_unique unique (user_id, book_id);
  end if;
end $$;

create table if not exists public.user_notes (
  id bigint generated by default as identity primary key,
  user_library_id bigint not null,
  title text not null,
  note text not null,
  created_at timestamptz not null default now(),
  constraint user_notes_user_library_fkey
    foreign key (user_library_id)
    references public.user_library (id)
    on delete cascade
);
alter table public.user_notes enable row level security;

drop policy if exists "Users can view their notes" on public.user_notes;
drop policy if exists "Users can add their notes" on public.user_notes;
drop policy if exists "Users can update their notes" on public.user_notes;
drop policy if exists "Users can delete their notes" on public.user_notes;

alter table public.user_notes
  add column if not exists user_library_id bigint;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_notes'
      and column_name = 'user_id'
  ) and exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_notes'
      and column_name = 'book_id'
  ) then
    update public.user_notes as notes
    set user_library_id = library.id
    from public.user_library as library
    where library.user_id = notes.user_id
      and library.book_id::text = notes.book_id::text
      and notes.user_library_id is null;

    if exists (
      select 1 from public.user_notes where user_library_id is null
    ) then
      raise exception 'Could not match every note to a user_library row';
    end if;

    alter table public.user_notes
      drop constraint if exists user_notes_user_book_fkey;
    alter table public.user_notes
      drop constraint if exists user_notes_book_id_fkey;
    alter table public.user_notes drop column user_id;
    alter table public.user_notes drop column book_id;
  end if;

  alter table public.user_notes
    alter column user_library_id set not null;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.user_notes'::regclass
      and conname = 'user_notes_user_library_fkey'
  ) then
    alter table public.user_notes
      add constraint user_notes_user_library_fkey
      foreign key (user_library_id)
      references public.user_library (id)
      on delete cascade;
  end if;
end;
$$;

create index if not exists user_notes_library_created_at_idx
  on public.user_notes (user_library_id, created_at desc);

create or replace function public.recalculate_book_rate(p_book_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.books
  set rate = coalesce((
    select round(avg(rate)::numeric, 1)
    from public.user_library
    where book_id = p_book_id
      and status::text = 'read'
      and rate > 0
  ), 0)
  where id = p_book_id;
end;
$$;

create or replace function public.refresh_book_rate_after_library_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.recalculate_book_rate(old.book_id);
    return old;
  end if;

  if tg_op = 'UPDATE' and old.book_id is distinct from new.book_id then
    perform public.recalculate_book_rate(old.book_id);
  end if;
  perform public.recalculate_book_rate(new.book_id);
  return new;
end;
$$;

drop trigger if exists refresh_book_rate on public.user_library;
create trigger refresh_book_rate
  after insert or update of status, rate, book_id or delete
  on public.user_library
  for each row execute procedure public.refresh_book_rate_after_library_change();

update public.books as books
set rate = coalesce((
  select round(avg(library.rate)::numeric, 1)
  from public.user_library as library
  where library.book_id = books.id
    and library.status::text = 'read'
    and library.rate > 0
), 0);

drop policy if exists "Users can view their profile" on public.profiles;
create policy "Users can view their profile"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "Users can update their profile" on public.profiles;
create policy "Users can update their profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Keep role changes out of the client API while allowing profile edits.
revoke update on public.profiles from authenticated;
grant update (username, picture, privacy) on public.profiles to authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and lower(trim(coalesce(role, ''))) = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "Admins can view profiles" on public.profiles;
create policy "Admins can view profiles"
  on public.profiles for select
  to authenticated
  using (public.is_admin());

drop policy if exists "Users can view public profiles" on public.profiles;
drop policy if exists "Users can view reader profiles" on public.profiles;
create policy "Users can view reader profiles"
  on public.profiles for select
  to authenticated
  using (lower(trim(coalesce(role, ''))) <> 'admin');

drop policy if exists "Authenticated users can view books" on public.books;
create policy "Authenticated users can view books"
  on public.books for select
  to authenticated
  using (true);

grant select, insert, update, delete on public.books to authenticated;
drop policy if exists "Admins can manage books" on public.books;
create policy "Admins can manage books"
  on public.books for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "Authenticated users can import Google Books" on public.books;
create policy "Authenticated users can import Google Books"
  on public.books for insert
  to authenticated
  with check (
    (google_books_id is not null and btrim(google_books_id) <> '')
    or (isbn is not null and btrim(isbn) <> '')
  );

drop policy if exists "Admins can manage book pictures" on storage.objects;
create policy "Admins can manage book pictures"
  on storage.objects for all
  to authenticated
  using (bucket_id = 'Book pictures' and public.is_admin())
  with check (bucket_id = 'Book pictures' and public.is_admin());

drop policy if exists "Users can manage their profile pictures" on storage.objects;
create policy "Users can manage their profile pictures"
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'profile pictures'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'profile pictures'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "Users can view their library" on public.user_library;
create policy "Users can view their library"
  on public.user_library for select
  using (auth.uid() = user_id);

drop policy if exists "Admins can view all user libraries" on public.user_library;
create policy "Admins can view all user libraries"
  on public.user_library for select
  to authenticated
  using (public.is_admin());

drop policy if exists "Users can view public profile libraries" on public.user_library;
create policy "Users can view public profile libraries"
  on public.user_library for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles
      where profiles.id = user_library.user_id
        and profiles.privacy = 'public'
    )
  );

drop policy if exists "Users can add to their library" on public.user_library;
create policy "Users can add to their library"
  on public.user_library for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their library" on public.user_library;
create policy "Users can update their library"
  on public.user_library for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant delete on public.user_library to authenticated;

drop policy if exists "Users can remove from their library" on public.user_library;
create policy "Users can remove from their library"
  on public.user_library for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.user_notes to authenticated;

drop policy if exists "Users can view their notes" on public.user_notes;
create policy "Users can view their notes"
  on public.user_notes for select
  to authenticated
  using (
    exists (
      select 1 from public.user_library
      where user_library.id = user_notes.user_library_id
        and user_library.user_id = auth.uid()
    )
  );

drop policy if exists "Users can add their notes" on public.user_notes;
create policy "Users can add their notes"
  on public.user_notes for insert
  to authenticated
  with check (
    exists (
      select 1 from public.user_library
      where user_library.id = user_notes.user_library_id
        and user_library.user_id = auth.uid()
    )
  );

drop policy if exists "Users can update their notes" on public.user_notes;
create policy "Users can update their notes"
  on public.user_notes for update
  to authenticated
  using (
    exists (
      select 1 from public.user_library
      where user_library.id = user_notes.user_library_id
        and user_library.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.user_library
      where user_library.id = user_notes.user_library_id
        and user_library.user_id = auth.uid()
    )
  );

drop policy if exists "Users can delete their notes" on public.user_notes;
create policy "Users can delete their notes"
  on public.user_notes for delete
  to authenticated
  using (
    exists (
      select 1 from public.user_library
      where user_library.id = user_notes.user_library_id
        and user_library.user_id = auth.uid()
    )
  );