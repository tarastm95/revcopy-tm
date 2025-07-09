#!/bin/bash
set -e

# PostgreSQL Initialization Script for RevCopy

echo "Initializing RevCopy database..."

# Create additional databases if needed
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Enable required extensions
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    
    -- Create indexes for performance
    -- (These will be handled by application migrations)
    
    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;
    
    -- Log initialization
    INSERT INTO pg_stat_statements_info(dealloc) VALUES (0);
EOSQL

echo "RevCopy database initialized successfully!" 