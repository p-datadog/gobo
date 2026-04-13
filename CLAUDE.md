# Development Guidelines for Claude

## Commit Every Change

Commit after every logical change in the same response that makes the change — don't accumulate uncommitted work. If specs pass, commit. Do not wait for the user to ask. A change without a commit in the same response is a violation of this rule.

## Running Commands

Always prefix Ruby/Rails commands with `bundle exec`. Never run `ruby`, `rails`, `rake`, `rspec`, or other gem-provided executables without `bundle exec`.

## Scripts

All script logic must live in files under `lib/` so it can be unit tested. `bin/` scripts are thin wrappers that parse CLI options and call into `lib/`. Add specs in `spec/lib/` for all lib code.

Shell scripts must be POSIX-compatible (`#!/bin/sh`). No bashisms — no `[[ ]]`, no `local` in non-function context, no `set -o pipefail`, no arrays, no `$()` process substitution where backticks differ, no `source` (use `.`). Use `shellcheck -s sh` to verify.

## Exception Reporting

When logging exceptions, always use the pattern `#{e.class}: #{e}` to include both the exception class and message.

**Required pattern:**
```ruby
rescue => e
  Rails.logger.error "Error fetching data: #{e.class}: #{e}"
end
```

**Do not use:**
```ruby
rescue => e
  Rails.logger.error "Error fetching data: #{e.message}"
end
```

## UI Usability

- Links must wrap the full visible element (the entire path, the entire label), not a small annotation like `[src]` next to it.
- Never use `display: none` on content the user will need. Show a default state instead (e.g. "Click to trigger" instead of hiding).
- AJAX error responses must always be shown to the user, never swallowed.
- Never collapse UI elements by default. Always use `open` attribute on `<details>` tags and `in` class on Bootstrap collapse elements.

## UI Navigation

All UI should be navigable from the homepage via links or buttons. There should be no orphaned controllers or actions — every endpoint must be reachable by following links from the homepage.

## Feature Discoverability

The homepage should have UI elements and/or prose describing available features so that they are discoverable. Users should be able to understand what the app demonstrates without prior knowledge.

## DI Demo Design

Each DI feature demo should require exactly ONE probe to demonstrate all cases. Design a single method that exercises every variation of the feature, called multiple times with different parameters. This minimizes user setup and maximizes what a single probe captures.

Controller actions that trigger DI-instrumented code MUST rescue all exceptions. The UI must work whether or not DI probes are set — DI observes silently, it does not control the user experience. Never design a demo where the UI breaks if DI is absent or misconfigured.

## JSON Endpoints for Diagnostic Pages

Every controller action that displays diagnostic data (memory stats, probes, code tracker,
etc.) must support a JSON response via `respond_to`. This allows querying from the CLI
(`curl localhost:3000/memory.json | jq .`) without needing a browser. Add a JSON link in
the HTML view header so the endpoint is discoverable.

## Tracer Integration

When writing code that calls dd-trace-rb configuration APIs, read the actual settings file in the tracer to verify the setting path exists. Do not guess API shapes. The tracer is a local checkout — reading the source is instant.

## Test Coverage

All code changes must have test coverage. When adding or modifying models, controllers, or lib classes, write or update specs in the corresponding `spec/` file.

When fixing a bug, the fix must be accompanied by a test that would have caught the bug. The test should describe the specific scenario that triggered it (e.g. "does not raise when targets is a base64-encoded string").

Run the full test suite before committing. If any tests fail for any reason — including pre-existing failures unrelated to your changes — investigate and fix them. Commit fixes for pre-existing failures as separate commits before committing your own work. Do not dismiss failures as "pre-existing" or "not my problem."

Exception: documentation-only changes (CLAUDE.md, README, comments) that cannot affect test outcomes may be committed without running the full suite.

Tests for diagnostic/status pages must verify that displayed values are correct, not just that they are present. `expect(json).to include('key')` only verifies the key exists. `expect(json['key']).to eq(expected)` verifies the value is truthful. Status pages that display wrong values with confidence are worse than pages that display nothing.

When the controller integrates with dd-trace-rb, include a test context simulating a tracer version where the feature does not exist (e.g. stub `respond_to?(:symbol_database)` to return false) to verify graceful degradation.

The test command is:
```
DD_TRACER=/real.home/claude-dtr-2/dtr bundle exec rspec
```
