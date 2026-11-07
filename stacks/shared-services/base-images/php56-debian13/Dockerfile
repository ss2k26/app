FROM debian:trixie-slim

WORKDIR /var/www/html

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    git \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ trixie main" \
    > /etc/apt/sources.list.d/php.list

RUN apt-get update && apt-get install -y \
    php5.6-fpm \
    php5.6-cli \
    php5.6-mysql \
    php5.6-mbstring \
    php5.6-zip \
    php5.6-gd \
    php5.6-xml \
    php5.6-curl \
    php5.6-bcmath \
    php5.6-opcache \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:1.10.26 /usr/bin/composer /usr/bin/composer

RUN echo "session.upload_progress.enabled = Off" >> /etc/php/5.6/fpm/php.ini && \
    echo "session.upload_progress.enabled = Off" >> /etc/php/5.6/cli/php.ini

RUN groupadd -g 1000 www && useradd -u 1000 -ms /bin/bash -g www www

RUN mkdir -p /var/run/php && chown www:www /var/run/php && \
    sed -i 's|listen = /run/php/php5.6-fpm.sock|listen = /var/run/php/php5.6-fpm.sock|' /etc/php/5.6/fpm/pool.d/www.conf && \
    sed -i 's/user = www-data/user = www/' /etc/php/5.6/fpm/pool.d/www.conf && \
    sed -i 's/group = www-data/group = www/' /etc/php/5.6/fpm/pool.d/www.conf && \
    sed -i 's/;listen.owner = www-data/listen.owner = www/' /etc/php/5.6/fpm/pool.d/www.conf && \
    sed -i 's/;listen.group = www-data/listen.group = www/' /etc/php/5.6/fpm/pool.d/www.conf && \
    sed -i 's/;listen.mode = 0660/listen.mode = 0666/' /etc/php/5.6/fpm/pool.d/www.conf && \
    sed -i 's|error_log = /var/log/php5.6-fpm.log|error_log = /proc/self/fd/2|' /etc/php/5.6/fpm/php-fpm.conf && \
    sed -i 's/;daemonize = yes/daemonize = no/' /etc/php/5.6/fpm/php-fpm.conf

CMD ["/usr/sbin/php-fpm5.6", "-F"]
