#!/usr/bin/env bash

# Color definitions
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

# 🛠️ Function to create user and database
setup_user_and_database() {
    local username=$1
    local password=$2
    local db_name=$3

    echo -e "${CYAN}🔧 Setting up user: ${BOLD}$username${RESET}${CYAN} | database: ${BOLD}$db_name${RESET}"
    PGPASSWORD="$POSTGRES_PASSWORD" psql -v ON_ERROR_STOP=1 --quiet --host postgres --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
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
    echo -e "${GREEN}✅ Successfully configured: ${BOLD}$username${RESET}${GREEN} → ${BOLD}$db_name${RESET}"
}

echo -e "${BLUE}${BOLD}🚀 Starting PostgreSQL database initialization...${RESET}"

# 🔍 Auto-discover all DBINIT_*_USER environment variables
services_found=0

for user_var in $(env | grep "^DBINIT_.*_USER=" | cut -d'=' -f1); do
    # Extract service name from DBINIT_<SERVICE>_USER
    service_name=$(echo "$user_var" | sed 's/^DBINIT_//; s/_USER$//')

    # Get variable values
    password_var="DBINIT_${service_name}_PASSWORD"
    name_var="DBINIT_${service_name}_NAME"
    user_value=$(eval echo \$${user_var})
    password_value=$(eval echo \$${password_var})
    name_value=$(eval echo \$${name_var})

    # Check if all required variables are set
    if [[ -n "$user_value" && -n "$password_value" && -n "$name_value" ]]; then
        echo -e "${BLUE}📦 Found service: ${BOLD}$service_name${RESET}"
        setup_user_and_database "$user_value" "$password_value" "$name_value"
        ((services_found++))
    else
        echo -e "${YELLOW}⚠️  Incomplete config for ${BOLD}$service_name${RESET}${YELLOW}:${RESET}"
        echo -e "   👤 User: ${user_value:-${RED}❌ MISSING${RESET}}"
        echo -e "   🔐 Password: ${password_value:+${GREEN}✅ SET${RESET}}${password_value:-${RED}❌ MISSING${RESET}}"
        echo -e "   📁 Database: ${name_value:-${RED}❌ MISSING${RESET}}"
    fi
done

if [ $services_found -eq 0 ]; then
    echo -e "${YELLOW}😴 No database services found with DBINIT_*_USER pattern${RESET}"
else
    echo -e "${GREEN}${BOLD}🎉 PostgreSQL initialization completed!${RESET} ${GREEN}(${BOLD}$services_found${RESET}${GREEN} services configured)${RESET}"
fi
