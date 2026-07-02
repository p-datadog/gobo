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
    [
      describe_target('Positional arguments', ProbeDemo.instance_method(:positional_args)),
      describe_target('Keyword arguments', ProbeDemo.instance_method(:keyword_args)),
    ]
  end

  # Coordinates are read from the live method object so they stay accurate if
  # the demo methods move.
  def describe_target(label, method)
    file, line = method.source_location
    {
      label: label,
      class_name: method.owner.name,
      method_name: method.name.to_s,
      file: file,
      line: line,
      parameters: method.parameters.map { |type, name| {type: type.to_s, name: name.to_s} },
    }
  end
end
