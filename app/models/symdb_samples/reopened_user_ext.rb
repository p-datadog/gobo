# frozen_string_literal: true

# Reopens SymdbSamples::ReopenedUser to add an additional STATIC_FIELD
# from a second source file. See reopened_user.rb for the primary
# definition, and manual-test-plan.md Test 12 for what this exercises.
module SymdbSamples
  # Marker module so Zeitwerk's filename->constant rule resolves -
  # without it eager_load raises Zeitwerk::NameError on this file.
  # The reopening of ReopenedUser below is the substantive content.
  module ReopenedUserExt
  end

  class ReopenedUser
    SESSION_TIMEOUT = 3600
  end
end
