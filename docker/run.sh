#!/bin/bash

set -euo pipefail

bundle exec rake db:migrate

bundle exec rake create_user

export DD_DYNAMIC_INSTRUMENTATION_ENABLED=true
export DD_SYMBOL_DATABASE_UPLOAD_ENABLED=true

export RAILS_SERVE_STATIC_FILES=true

export DD_TRACE_DEBUG=true

bundle exec rails s -p 8080 -b 0.0.0.0 -e production
