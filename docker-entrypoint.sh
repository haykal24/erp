#!/bin/bash

set -e

echo "Starting Laravel application setup..."

# Create .env file from environment variables if it doesn't exist
if [ ! -f /var/www/.env ]; then
    echo "Creating .env file from .env.example..."
    cp /var/www/.env.example /var/www/.env
    
    # Generate APP_KEY if not set in environment
    if [ -z "$APP_KEY" ]; then
        echo "Generating APP_KEY..."
        php artisan key:generate --force
    else
        echo "Using APP_KEY from environment variables..."
        # Update .env with APP_KEY from environment
        sed -i "s|APP_KEY=.*|APP_KEY=$APP_KEY|g" /var/www/.env
    fi
else
    # Update .env with environment variables if they exist
    echo "Updating .env file with environment variables..."
    
    # List of environment variables to sync
    env_vars=(
        "APP_NAME" "APP_ENV" "APP_KEY" "APP_DEBUG" "APP_TIMEZONE" "APP_URL"
        "APP_LOCALE" "APP_FALLBACK_LOCALE" "APP_FAKER_LOCALE"
        "APP_CURRENCY" "APP_MAINTENANCE_DRIVER"
        "DB_CONNECTION" "DB_HOST" "DB_PORT" "DB_DATABASE" "DB_USERNAME" "DB_PASSWORD"
        "SESSION_DRIVER" "SESSION_LIFETIME" "SESSION_ENCRYPT" "SESSION_PATH" "SESSION_DOMAIN"
        "BROADCAST_CONNECTION" "FILESYSTEM_DISK" "QUEUE_CONNECTION"
        "CACHE_STORE" "CACHE_PREFIX"
        "REDIS_CLIENT" "REDIS_HOST" "REDIS_PASSWORD" "REDIS_PORT"
        "MAIL_MAILER" "MAIL_HOST" "MAIL_PORT" "MAIL_USERNAME" "MAIL_PASSWORD" "MAIL_ENCRYPTION" "MAIL_FROM_ADDRESS" "MAIL_FROM_NAME"
    )
    
    for var in "${env_vars[@]}"; do
        if [ ! -z "${!var}" ]; then
            # Escape special characters for sed
            value=$(echo "${!var}" | sed 's/[[\.*^$()+?{|]/\\&/g')
            # Update or add the variable
            if grep -q "^${var}=" /var/www/.env; then
                sed -i "s|^${var}=.*|${var}=${value}|g" /var/www/.env
            else
                echo "${var}=${value}" >> /var/www/.env
            fi
        fi
    done
    
    # Generate APP_KEY if still empty
    if ! grep -q "APP_KEY=base64:" /var/www/.env && [ -z "$APP_KEY" ]; then
        echo "Generating APP_KEY..."
        php artisan key:generate --force
    fi
    
    # Ensure APP_URL uses HTTPS if in production
    if [ "$APP_ENV" = "production" ] || [ -z "$APP_ENV" ]; then
        if grep -q "^APP_URL=" /var/www/.env; then
            # Replace http:// with https:// in APP_URL
            sed -i 's|^APP_URL=http://|APP_URL=https://|g' /var/www/.env
            echo "Updated APP_URL to use HTTPS"
        fi
    fi
fi

# Clear config cache to ensure environment variables are reloaded
echo "Clearing config cache..."
php artisan config:clear || true

# Wait for database to be ready (optional, uncomment if needed)
# echo "Waiting for database..."
# while ! nc -z ${DB_HOST} ${DB_PORT}; do
#   sleep 0.1
# done
# echo "Database is ready!"

# Run migrations
echo "Running migrations..."
php artisan migrate --force

# Run seeders (creates superadmin and roles)
echo "Running seeders..."
php artisan db:seed --force || echo "Warning: Seeding failed or already completed"

# Cache configuration
echo "Caching configuration..."
php artisan config:cache

# Cache routes
echo "Caching routes..."
php artisan route:cache

# Publish Filament assets (if not already published)
echo "Publishing Filament assets..."
php artisan filament:assets || true

# Publish Livewire assets (if needed)
echo "Publishing Livewire assets..."
php artisan livewire:publish --assets || true

# Cache views (skip if fails, views will be compiled on-demand)
echo "Caching views..."
php artisan view:cache || echo "Warning: View cache failed, views will be compiled on-demand"

# Create storage link if it doesn't exist
if [ ! -L public/storage ]; then
    echo "Creating storage link..."
    php artisan storage:link
fi

# Set permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache
chmod -R 755 /var/www/storage /var/www/bootstrap/cache

# Clear application cache
echo "Clearing application cache..."
php artisan cache:clear

echo "Setup completed!"

# Remove any default Nginx sites
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "Testing Nginx configuration..."
nginx -t || echo "Warning: Nginx configuration test failed"

# Start PHP-FPM in background
php-fpm -D

# Start Nginx in foreground
exec nginx -g "daemon off;"
