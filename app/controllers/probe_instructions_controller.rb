class ProbeInstructionsController < ApplicationController
  def index
    @service = fetch_service
    @env = fetch_env
    @targets = probe_targets

    respond_to do |format|
      format.html
      format.json { render json: {service: @service, env: @env, targets: @targets} }
    end
  end

  private

  def probe_targets
    values = ProbeDemo.demo_arguments(user: current_user, count: Micropost.count)
    [
      describe_target('Positional arguments', ProbeDemo.instance_method(:args), values[:args]),
      describe_target('Keyword arguments', ProbeDemo.instance_method(:kw_args), values[:kw_args]),
    ]
  end

  # Coordinates are read from the live method object so they stay accurate if
  # the demo methods move. +values+ are the arguments actually sent, so the
  # Type column reports the real class of each argument.
  def describe_target(label, method, values)
    file, line = method.source_location
    {
      label: label,
      class_name: method.owner.name,
      method_name: method.name.to_s,
      file: file,
      line: line,
      parameters: method.parameters.map do |kind, name|
        {type: kind.to_s, name: name.to_s, value_type: values[name].class.name}
      end,
    }
  end
end
