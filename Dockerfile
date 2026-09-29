# syntax=docker/dockerfile:1
# check=error=true

# Dockerfile per la produzione, non per lo sviluppo. Con Kamal o a mano:
# docker build -t active-core .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name active-core active-core

# Per sviluppare in container vedi Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# RUBY_VERSION deve coincidere con .ruby-version
ARG RUBY_VERSION=4.0.5
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Cartella dell'app Rails
WORKDIR /rails

# Pacchetti di base
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 sqlite3 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Variabili di produzione e jemalloc per meno memoria e latenza.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Stage di build usa e getta per un'immagine finale più piccola
FROM base AS build

# Pacchetti necessari a compilare le gem
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Gem dell'applicazione
COPY Gemfile Gemfile.lock vendor ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disattiva la compilazione parallela per un bug di QEMU: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Codice dell'applicazione
COPY . .

# Precompila bootsnap per un avvio più veloce.
# -j 1 disattiva la compilazione parallela per un bug di QEMU: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompila gli asset senza bisogno di RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Stage finale dell'immagine
FROM base

# Per sicurezza gira come utente non root, proprietario dei soli file di runtime
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copia gli artefatti: gem e applicazione
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# L'entrypoint prepara il database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Di default avvia il server con Thruster; sovrascrivibile a runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
