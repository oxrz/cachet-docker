FROM composer:2.8.12

ARG GITHUB_TOKEN
ENV COMPOSER_TOKEN ${GITHUB_TOKEN}

RUN composer config --global github-oauth.github.com ${COMPOSER_TOKEN} \
 && git clone -b 3.x https://github.com/oxrz/cachet.git . \
 && apk update && apk add php-intl icu-dev postgresql-dev postgresql-client \
 && docker-php-ext-install pdo pdo_pgsql intl \
 && composer install --no-dev -o \
 && composer update cachethq/core \
 && cp .env.example .env \
 && php artisan key:generate

WORKDIR /app 
COPY entrypoint.sh .

EXPOSE 8000
ENTRYPOINT ["sh", "entrypoint.sh"]
