# Symdb controller: broken code, no tests, lying UI

**Applies to:** process

## What happened

The symdb controller was written with four compounding failures:

### 1. Broken code: called a nonexistent API

`upload_enabled?` checked `symbol_database.upload.enabled` — a setting path that does
not exist in dd-trace-rb. The actual setting is `symbol_database.enabled` (no `.upload`
sub-path). Because `respond_to?(:upload)` always returned false, the method always
returned false. The UI permanently displayed "Upload: Disabled" regardless of config.

```ruby
# What was written (broken)
def upload_enabled?
  defined?(Datadog) && Datadog.configuration.respond_to?(:symbol_database) &&
    Datadog.configuration.symbol_database.respond_to?(:upload) &&
    Datadog.configuration.symbol_database.upload.enabled
end

# What the actual setting path is
Datadog.configuration.symbol_database.enabled  # no .upload sub-path
```

### 2. No tests for correctness of status values

The tests only checked:
- HTTP 200
- JSON keys exist
- Assigned values are the right type (String, Symbol)

No test verified that `symdb_enabled` or `upload_enabled` returned **correct** values
against the actual tracer. A test like `expect(assigns(:symdb_enabled)).to eq(true)` —
which would have caught that `upload_enabled` is always false — was never written.

### 3. Not verified against the running tracer

The dd-trace-rb settings API was called without reading the settings source to confirm
the path exists. The code was written from an assumption about the API shape
(`symbol_database.upload.enabled`) that was never verified against the actual
`<dtr>/lib/datadog/symbol_database/configuration/settings.rb`. The settings file shows
a flat `symbol_database.enabled` — no nested `upload` group.

### 4. Lying in the UI

The view displayed a confident status label:

```
Upload: [Disabled]
```

This is a red "Disabled" badge — it presents as a factual statement about the system's
configuration. In reality, the check that produced this value was broken. The label was
always "Disabled" because the code path never reached an actual setting. The UI lied to
the user with high confidence.

## Root cause

The code was written by guessing the dd-trace-rb settings API shape instead of reading
it. The guess was wrong (`symbol_database.upload.enabled` instead of
`symbol_database.enabled`). The `respond_to?` guard silently swallowed the error — the
nonexistent path didn't raise, it just returned false. The rescue block also ensured no
error would surface. The combination of guess + silent fallback + no correctness tests
produced code that looked like it worked (200 OK, no errors, labels rendered) while
displaying false information.

The tests validated structure (keys exist, types match, HTTP status) but not semantics
(are the values correct). A status page that returns `{"upload_enabled": false}` passes
a structural test but lies to the user if the feature is actually enabled.

The tracer compatibility issue compounds this: the controller must work with tracer
versions that don't have `Datadog::SymbolDatabase` at all. This was acknowledged in the
`symdb_enabled?` and `fetch_component_status` methods (which guard with
`defined?(Datadog::SymbolDatabase)`), but `upload_enabled?` invented a setting path
instead of using the same guard pattern.

## Recommendations

1. **gobo CLAUDE.md:** Add rule: "When writing code that calls dd-trace-rb configuration
   APIs, read the actual settings file in the tracer to verify the setting path exists.
   Do not guess API shapes. The tracer is a local checkout — reading the source is
   instant."

2. **gobo CLAUDE.md:** Add to Test Coverage section: "Tests for diagnostic/status pages
   must verify that displayed values are correct, not just that they are present. A test
   that checks `expect(json).to include('symdb_enabled')` only verifies the key exists.
   A test that checks `expect(json['symdb_enabled']).to eq(true)` verifies the value is
   truthful. Status pages that display wrong values with confidence are worse than pages
   that display nothing."

3. **gobo CLAUDE.md:** Add to Test Coverage section: "When the controller integrates with
   dd-trace-rb, write a test that exercises the code path against the actual tracer (not
   just mocks). Include a test context simulating a tracer version where the feature does
   not exist (e.g. stub `respond_to?(:symbol_database)` to return false) to verify
   graceful degradation."
