#!/usr/bin/env bash
set -e

# Function to create user and database
setup_user_and_database() {
    local username=$1
    local password=$2
    local db_name=$3

    echo "Setting up $username user and database..."
    PGPASSWORD="$POSTGRES_PASSWORD" psql -v ON_ERROR_STOP=1 --host postgres --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        -- Create user if not exists, update password if exists
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${username}') THEN
                CREATE USER ${username} WITH PASSWORD '${password}';
            ELSE
                ALTER USER ${username} WITH PASSWORD '${password}';
            END IF;
        END
        \$\$;

        -- Create database if not exists
        SELECT 'CREATE DATABASE ${db_name} OWNER ${username}'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec
EOSQL
}

echo "Starting PostgreSQL database initialization..."

# Setup n8n user and database
setup_user_and_database "${N8N_DB_USER}" "${N8N_DB_PASSWORD}" "${N8N_DB_NAME}"

# Setup authentik user and database
setup_user_and_database "${AUTHENTIK_DB_USER}" "${AUTHENTIK_DB_PASSWORD}" "${AUTHENTIK_DB_NAME}"

# Setup zitadel user and database
setup_user_and_database "${ZITADEL_DB_USER}" "${ZITADEL_DB_PASSWORD}" "${ZITADEL_DB_NAME}"

echo "PostgreSQL database initialization completed successfully!"
