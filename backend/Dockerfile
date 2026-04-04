FROM php:8.3-cli-alpine

WORKDIR /var/www

# System dependencies and PHP extensions required by Laravel
RUN apk add --no-cache \
    bash \
    git \
    unzip \
    libzip-dev \
    libpq-dev \
    icu-dev \
    oniguruma-dev \
    postgresql-client \
    && docker-php-ext-install \
    bcmath \
    intl \
    pdo_pgsql \
    zip

# Install Composer from official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install PHP dependencies first for better layer caching
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader --no-scripts

# Copy application source
COPY . .

# Remove cached bootstrap manifests generated in local/dev environments
RUN rm -f bootstrap/cache/*.php

# Ensure Laravel writable directories have proper permissions
RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

EXPOSE 9999

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=9999"]
