-- Initialize Supabase roles with passwords.
-- The supabase/postgres image creates roles without passwords.
-- This script sets them using the POSTGRES_PASSWORD env var.
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER ROLE authenticator WITH PASSWORD :'pgpass';
ALTER ROLE supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER ROLE supabase_admin WITH PASSWORD :'pgpass';
