# DI method-probe demo targets. Both methods are invoked on every home page
# load (StaticPagesController#invoke_probe_demo), so a method probe set on
# either one fires whenever the home page is hit. See the Probe Instructions
# page (ProbeInstructionsController) for the resolved coordinates.
class ProbeDemo
  # Probe target exercising positional arguments.
  def positional_args(user_id, action, count)
    "user_id=#{user_id} action=#{action} count=#{count}"
  end

  # Probe target exercising keyword arguments.
  def keyword_args(query:, limit:, offset:)
    "query=#{query} limit=#{limit} offset=#{offset}"
  end
end
