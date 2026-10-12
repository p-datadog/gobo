require_relative '../../lib/stress/thread_stress'

# Renders the thread stress report as JSON.
class ThreadStressController < ActionController::Base
  # AGENTS.md requires all demo actions to rescue exceptions.
  def index
    stress = Stress::ThreadStress.new
    stress.thread_count = 20
    render json: stress.handle
  end
end
