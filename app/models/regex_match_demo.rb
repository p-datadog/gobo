# DI expression-language `matches` timeout demo target. A single method probe
# set on RegexMatchDemo#check with the condition `matches(haystack, PATTERN)`
# runs PATTERN against every haystack passed to #check. PATTERN is a
# catastrophic-backtracking regexp, so the pathological input would block the
# request thread indefinitely without the per-match timeout added in
# dd-trace-rb PR #5908, and is bounded to Evaluator::MATCHES_TIMEOUT_SECONDS
# (500ms) with it.
#
# #check itself never runs the regexp; the app only measures wall-clock time.
# The regexp runs inside DI while it evaluates the probe condition, so the
# timing difference is observable only while the probe is active.
class RegexMatchDemo
  # Catastrophic-backtracking regexp used as the `matches` needle. Against a
  # run of "a" followed by a non-matching character the engine explores an
  # exponential number of paths before failing.
  PATTERN = "(a+)+$".freeze

  # Haystacks passed to #check, in order. The pathological entry triggers the
  # exponential backtracking that the timeout bounds.
  def self.inputs
    [
      {label: "Benign match", haystack: "aaaa"},
      {label: "Benign non-match", haystack: "hello world"},
      {label: "Pathological (catastrophic backtracking)", haystack: ("a" * 30) + "!"},
    ]
  end

  # Coordinates read from the live method object so they stay accurate if the
  # method moves. Mirrors ProbeInstructionsController#describe_target.
  def self.probe_target
    method = instance_method(:check)
    file, line = method.source_location
    {
      class_name: method.owner.name,
      method_name: method.name.to_s,
      file: file,
      line: line,
    }
  end

  # Calls #check for each input, measuring the wall-clock time of each call.
  # While a probe with a `matches` condition is active, that time includes
  # DI's synchronous condition evaluation (the regexp match). Each call is
  # rescued so a single failure does not abort the run.
  def self.run
    demo = new
    inputs.map do |input|
      haystack = input[:haystack]
      result = nil
      error = nil
      elapsed = Benchmark.realtime do
        result = demo.check(input[:label], haystack)
      rescue => e
        error = e
      end
      {
        label: input[:label],
        bytes: haystack.bytesize,
        length: result,
        elapsed_ms: (elapsed * 1000).round(1),
        error: error && "#{error.class}: #{error}",
      }
    end
  end

  # DI probe target. The body is intentionally trivial; the regexp runs in DI
  # during condition evaluation, not here.
  def check(label, haystack)
    haystack.length
  end
end
