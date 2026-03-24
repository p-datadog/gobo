# Development Guidelines for Claude

## Running Commands

Always prefix Ruby/Rails commands with `bundle exec`. Never run `ruby`, `rails`, `rake`, `rspec`, or other gem-provided executables without `bundle exec`.

## Scripts

All script logic must live in files under `lib/` so it can be unit tested. `bin/` scripts are thin wrappers that parse CLI options and call into `lib/`. Add specs in `spec/lib/` for all lib code.

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

## UI Elements

Never collapse UI elements by default. Always use `open` attribute on `<details>` tags and `in` class on Bootstrap collapse elements.

## UI Navigation

All UI should be navigable from the homepage via links or buttons. There should be no orphaned controllers or actions — every endpoint must be reachable by following links from the homepage.

## Feature Discoverability

The homepage should have UI elements and/or prose describing available features so that they are discoverable. Users should be able to understand what the app demonstrates without prior knowledge.

## DI Demo Design

Each DI feature demo should require exactly ONE probe to demonstrate all cases. Design a single method that exercises every variation of the feature, called multiple times with different parameters. This minimizes user setup and maximizes what a single probe captures.

Controller actions that trigger DI-instrumented code MUST rescue all exceptions. The UI must work whether or not DI probes are set — DI observes silently, it does not control the user experience. Never design a demo where the UI breaks if DI is absent or misconfigured.

## Test Coverage

All code changes must have test coverage. When adding or modifying models, controllers, or lib classes, write or update specs in the corresponding `spec/` file. Specs must pass before committing.

When fixing a bug, the fix must be accompanied by a test that would have caught the bug. The test should describe the specific scenario that triggered it (e.g. "does not raise when targets is a base64-encoded string").

The test command is:
```
DD_TRACER=/real.home/claude-dtr-2/dtr bundle exec rspec
```
