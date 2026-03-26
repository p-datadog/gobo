#!/bin/bash

set -euo pipefail

# IFS=':' read -r DD_AGENT_HOST DD_TRACE_AGENT_PORT <<< "$TRACE_AGENT_URL"

# export DD_AGENT_HOST
# export DD_TRACE_AGENT_PORT

bundle exec rake db:migrate

bundle exec rake create_user

export DD_DYNAMIC_INSTRUMENTATION_ENABLED=true
export DD_SYMBOL_DATABASE_UPLOAD_ENABLED=true

export RAILS_SERVE_STATIC_FILES=true

export DD_TRACE_DEBUG=true

bundle exec rails s -p 8080 -b 0.0.0.0 -e production
