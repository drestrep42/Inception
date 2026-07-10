#!/bin/bash

set -e

if [ -n "$MYSQL_ROOT_PASSWORD_FILE" ] && [ -f "$MYSQL_ROOT_PASSWORD_FILE" ]; then
    MYSQL_ROOT_PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE")
    export MYSQL_ROOT_PASSWORD
fi

if [ -n "$MYSQL_PASSWORD_FILE" ] && [ -f "$MYSQL_PASSWORD_FILE" ]; then
    MYSQL_PASSWORD=$(cat "$MYSQL_PASSWORD_FILE")
    export MYSQL_PASSWORD
fi

mysql_root() {
    if mysql --socket=/run/mysqld/mysqld.sock -u root -e 'SELECT 1' >/dev/null 2>&1; then
        mysql --socket=/run/mysqld/mysqld.sock -u root "$@"
        return $?
    fi

    if [ -n "$MYSQL_ROOT_PASSWORD" ] && mysql --socket=/run/mysqld/mysqld.sock -u root -p"$MYSQL_ROOT_PASSWORD" -e 'SELECT 1' >/dev/null 2>&1; then
        mysql --socket=/run/mysqld/mysqld.sock -u root -p"$MYSQL_ROOT_PASSWORD" "$@"
        return $?
    fi

    return 1
}

echo "Starting MariaDB initialization..."

# Initialize MySQL data directory if it doesn't exist
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

# Start the server (no networking for setup)
echo "Starting temporary MariaDB server for setup..."
mysqld --skip-networking --socket=/run/mysqld/mysqld.sock --user=mysql &
pid="$!"

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
until mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; do
    sleep 1
done
echo "MariaDB is ready!"

# Run setup SQL: create database and users
echo "Running setup SQL..."
mysql_root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE OR REPLACE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# Shut down temporary server
echo "Shutting down temporary MariaDB..."
if ! mysqladmin --socket=/run/mysqld/mysqld.sock -u root shutdown >/dev/null 2>&1; then
    mysqladmin --socket=/run/mysqld/mysqld.sock -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
fi

# Wait for shutdown
wait "$pid" || true

# Start MariaDB normally (with networking)
echo "Initialization complete. Starting MariaDB..."
exec mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock