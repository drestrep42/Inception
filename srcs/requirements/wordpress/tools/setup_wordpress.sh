#!/bin/bash
set -e

WP_PATH="/var/www/html"

load_secret() {
    local value_name="$1"
    local file_name="$2"

    if [ -n "${!file_name}" ] && [ -f "${!file_name}" ]; then
        printf -v "$value_name" '%s' "$(cat "${!file_name}")"
        export "$value_name"
    fi
}

# Read password from secret file
load_secret WORDPRESS_DB_USER WORDPRESS_DB_USER_FILE
load_secret WORDPRESS_DB_PASSWORD WORDPRESS_DB_PASSWORD_FILE
load_secret WORDPRESS_ADMIN_USER WORDPRESS_ADMIN_USER_FILE
load_secret WORDPRESS_ADMIN_PASSWORD WORDPRESS_ADMIN_PASSWORD_FILE
load_secret WORDPRESS_ADMIN_EMAIL WORDPRESS_ADMIN_EMAIL_FILE
load_secret WORDPRESS_NEW_USER WORDPRESS_NEW_USER_FILE
load_secret WORDPRESS_NEW_USER_PASSWORD WORDPRESS_NEW_USER_PASSWORD_FILE
load_secret WORDPRESS_NEW_USER_EMAIL WORDPRESS_NEW_USER_EMAIL_FILE

echo "Setting up WordPress..."

# Download and configure WordPress if not present
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo "Downloading WordPress..."
    wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz
    tar -xzf /tmp/wordpress.tar.gz -C /tmp
    rm /tmp/wordpress.tar.gz

    # Copy only missing files (avoid overwriting existing content)
    cp -rn /tmp/wordpress/* "$WP_PATH" || true
    rm -rf /tmp/wordpress

    # Fetch security salts from WordPress API
    WP_SALTS=$(wget -qO- https://api.wordpress.org/secret-key/1.1/salt/)

    # Create wp-config.php
    cat > "$WP_PATH/wp-config.php" << EOF
<?php
define('DB_NAME', '${WORDPRESS_DB_NAME}');
define('DB_USER', '${WORDPRESS_DB_USER}');
define('DB_PASSWORD', '${WORDPRESS_DB_PASSWORD}');
define('DB_HOST', '${WORDPRESS_DB_HOST}');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

\$table_prefix = '${WORDPRESS_TABLE_PREFIX:-wp_}';

${WP_SALTS}

define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
    define('ABSPATH', __DIR__ . '/');

require_once ABSPATH . 'wp-settings.php';
EOF

    # Set secure permissions
    find "$WP_PATH" -type d -exec chmod 750 {} \;
    find "$WP_PATH" -type f -exec chmod 640 {} \;
    chown -R www-data:www-data "$WP_PATH"

    echo "WordPress setup complete."
else
    echo "WordPress already initialized, skipping setup."
fi

if [ ! -x /usr/local/bin/wp ]; then
    echo "Installing wp-cli..."
    curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
    chmod +x /usr/local/bin/wp
fi

wait_for_database() {
    attempts=30

    until wp --allow-root --path="$WP_PATH" db check >/dev/null 2>&1; do
        attempts=$((attempts - 1))
        if [ "$attempts" -le 0 ]; then
            return 1
        fi
        sleep 1
    done
}

ensure_wordpress_users() {
    if [ -n "$WORDPRESS_NEW_USER" ] && [ -n "$WORDPRESS_NEW_USER_PASSWORD" ] && [ -n "$WORDPRESS_NEW_USER_EMAIL" ]; then
        if ! wp --allow-root --path="$WP_PATH" user get "$WORDPRESS_NEW_USER" >/dev/null 2>&1; then
            wp --allow-root --path="$WP_PATH" user create \
                "$WORDPRESS_NEW_USER" \
                "$WORDPRESS_NEW_USER_EMAIL" \
                --role=subscriber \
                --user_pass="$WORDPRESS_NEW_USER_PASSWORD"
        fi
    fi
}

if ! wp --allow-root --path="$WP_PATH" core is-installed >/dev/null 2>&1; then
    echo "Waiting for WordPress database..."
    wait_for_database

    echo "Installing WordPress core..."
    wp --allow-root --path="$WP_PATH" core install \
        --url="https://${DOMAIN_NAME:-localhost}" \
        --title="${WORDPRESS_SITE_TITLE:-Inception}" \
        --admin_user="$WORDPRESS_ADMIN_USER" \
        --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
        --admin_email="$WORDPRESS_ADMIN_EMAIL"
fi

ensure_wordpress_users

echo "Starting PHP-FPM..."
exec php-fpm8.2 -F


