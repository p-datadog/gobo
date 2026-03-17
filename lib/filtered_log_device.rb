# Strips Datadog log injection prefixes from log output.
#
# Datadog's log injection feature prepends trace correlation context to every
# log message at the formatter level:
#   [dd.env=x dd.service=y dd.trace_id=z dd.span_id=w ddsource=ruby]
#
# By filtering at the IO level (after all formatters have run), this cleanly
# removes the prefix regardless of how Datadog wraps the formatter.
class FilteredLogDevice
  DD_TRACE_PREFIX = /\[dd\.\w+=\S+(?:\s+dd\.\w+=\S+)* ddsource=ruby\] /

  def initialize(io)
    @io = io
  end

  def write(msg)
    @io.write(msg.to_s.gsub(DD_TRACE_PREFIX, ''))
  end

  def close
    @io.close
  end

  def flush
    @io.flush
  end

  def sync
    @io.sync
  end

  def sync=(val)
    @io.sync = val
  end

  def fileno
    @io.fileno
  end
end
