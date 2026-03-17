# Development Guidelines for Claude

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

## Test Coverage

All code changes must have test coverage. When adding or modifying models, controllers, or lib classes, write or update tests in the corresponding `test/` file. Tests must pass before committing.
