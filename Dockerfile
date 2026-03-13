FROM registry.ddbuild.io/images/base/gbi-ubuntu_2204:release as app

USER root

ARG  DD_TRACER

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      build-essential nodejs yarnpkg tzdata git curl \
      ruby ruby-bundler ruby-dev libsqlite3-dev libyaml-dev && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app/

RUN ln -s yarnpkg /usr/bin/yarn

COPY sample_app_6th_ed/package.json .
COPY sample_app_6th_ed/yarn.lock .

# If running on new nodes:
#ENV NODE_OPTIONS=--openssl-legacy-provider

RUN yarn install && yarn cache clean

COPY sample_app_6th_ed/Gemfile .
COPY sample_app_6th_ed/Gemfile.lock .

# We have a Gemfile.lock for the application to keep dependencies other than
# datadog at known working versions.
# However, datadog dependency should be updated to the most recent permitted
# version.
RUN bundle install

# We need DD_TRACER for Gemfile resolution at runtime
ENV DD_TRACER=$DD_TRACER

RUN bundle update datadog

COPY sample_app_6th_ed .

# The environment in docker is different from the host.
# When bundle install runs it can change the lock file.
# The copy of the entire app then overwrites the lock file again.
# We need to install again to fix the lock file (this execution of
# bundle install should not actually install anything).
RUN bundle install

# This fails silently if `yarn install` was not run.
# Debug other issues: give --trace argument to rake, and to
# debug webpacker claude said to set WEBPACKER_DEBUG=true but this did nothing.
RUN DD_TRACE_ENABLED=false WEBPACKER_DEBUG=true rake assets:precompile --trace

# https://stackoverflow.com/questions/29187296/rails-production-how-to-set-secret-key-base
ENV SECRET_KEY_BASE=a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0
ENV RAILS_ENV=production

COPY run.sh /

EXPOSE 8080

CMD ["bash", "/run.sh"]
