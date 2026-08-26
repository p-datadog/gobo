# Ruby Live Debugger Demo

A Datadog Dynamic Instrumentation (DI) and Symbol Database (SymDB) demo, based on
the [Rails Tutorial sample app](https://github.com/learnenough/rails_tutorial_sample_app_7th_ed).

## Features (routes)

- **DI probe demos** (`/debugger_test/*`) — method and line probes, exception
  capture, binary data, stdlib probes, regex timeouts.
- **Symbol Database** (`/symdb`) — symbol capture and upload; see also
  `bin/capture_symbols`, `bin/extract_symbols`, `bin/verify_symbols`.
- **Memory diagnostics** (`/memory`) — heap stats, GC, malloc trim.
- **DI status** (`/di_status`) — backend view of debugger sessions and probes for
  the service.
- **Probe instructions** (`/probe_instructions`).
- **Logs** (`/logs`) — query Datadog backend logs for the service.
- **Code tracker** (`/code_tracker`) — DI code-tracking state.
- **Stress** (`/stress/*`) — CPU/IO load endpoints.

## Getting started

Clone the repo and `cd` into it:

```sh
git clone https://github.com/p-datadog/gobo.git
cd gobo
```

`bin/run` is the entry point. It handles every prerequisite: `bundle install`,
`yarn install`, `rails db:migrate`, admin-user seed, `assets:precompile`,
`webpacker:compile`, `SECRET_KEY_BASE` generation for production, and the Datadog
env block (service, env, agent port, RC enablement in dev; DI/SymDB env vars are
left unset by default and only set with `-i`).

```sh
bin/run
```

`bin/run` seeds an admin user `admin@example.com` / `admin`. Running
`bundle exec rails db:seed` additionally creates the admin
`example@railstutorial.org` / `foobar`, 99 more users (password `password`),
microposts for the first several users, and follow relationships.

## Launching the app

Use `bin/run` to launch the app; run `puma`, `bin/rails server`, or `unicorn`
through it rather than on their own so the setup above happens first. Run
`bin/run --help` for the flag list.

**Implicit DI enablement testing:** by default `bin/run` leaves
`DD_DYNAMIC_INSTRUMENTATION_ENABLED` and `DD_SYMBOL_DATABASE_UPLOAD_ENABLED`
unset, so DI enablement is driven by Remote Configuration. Pass `-i` to force
enablement by env var, exporting both as `1`. Remote Configuration stays enabled
(on by default in production; add `-D` for development, which also enables RC and
telemetry).

**Faking the tracer version:** pass `-V VERSION` (long form
`--fake-tracer-version VERSION`) to report `VERSION` as the tracer library
version to the backend. It patches
`Datadog::Core::Environment::Identity.gem_datadog_version`, so telemetry, Remote
Configuration, process discovery, tags, and Dynamic Instrumentation all emit the
fake version. Use it to exercise the backend and web-ui version gates documented
in `lib/datadog_sim/languages.rb`; a fake below a gate suppresses the app's
DI/SymDB.

## Running the tests

```sh
DD_TRACER=~/dtr bundle exec rspec
```

The suite runs against whatever branch `~/dtr` is checked out on.

## DD_ENV Configuration

`DD_ENV` is set from the `-e` flag to `bin/run`, or from `DD_ENV` in the environment, otherwise it defaults to `Rails.env`. Dynamic Instrumentation requires an environment to be set — without it, DI probes will not be delivered to the application.

## DD_TRACER Configuration

Use `bin/use-tracer` to select which version of dd-trace-rb to use. It resolves shorthand specs and saves the result to `.dd-tracer`, so resolution only happens once. The `DD_TRACER` environment variable takes priority over the file if set.

```bash
bin/use-tracer pr:5111              # Use a PR's branch
bin/use-tracer branch:my-feature    # Use a branch from DataDog/dd-trace-rb
bin/use-tracer sha:abc1234          # Use a specific commit
bin/use-tracer fork:user/branch     # Use a branch from a fork
bin/use-tracer /path/to/local/copy  # Use a local checkout
bin/use-tracer 2.12.0               # Use a specific version
bin/use-tracer --reset              # Clear override (use latest release)
```

You can also set `DD_TRACER` directly with any of the above formats or a full git URL:

```bash
export DD_TRACER="git+https://github.com/DataDog/dd-trace-rb@branch-name"
```

## Simulating a Service (fake tracer / fake service)

`bin/simulate_service` simulates a Datadog-instrumented service to the backend without
running a real app. It impersonates a tracer in any supported language and sends the
minimum payloads needed for the backend to treat it as a live service:

- **Telemetry** — `app-started` event declaring DI enabled, then periodic heartbeats
- **Remote Config** — polls every 5s with `LIVE_DEBUGGING` + `LIVE_DEBUGGING_SYMBOL_DB`
  declared; prints any `upload_symbols: true` signal received from the backend
- **Traces** — a minimal synthetic trace to register the service in APM with git metadata

Useful for testing DI and SymDB backend behavior without a running Rails app. Also
handy for verifying that capability bits, tracer versions, and RC products are correct
for a given language — since the simulated service / fake service is fully configurable.

```bash
bundle exec bin/simulate_service --language java --service gobo
bundle exec bin/simulate_service --language python --no-traces
bundle exec bin/simulate_service --language ruby --dogfood-agent
```

Supported languages: `java`, `python`, `ruby`, `dotnet`, `go`, `node`, `php`

Optional flags: `--no-telemetry`, `--no-rc`, `--no-traces`, `--agent-port PORT`,
`--dogfood-agent`, `--staging-agent`, `--git-repo URL`, `--runtime-id ID`

Agent ports for `--dogfood-agent` and `--staging-agent` come from
[`config/agent_environments.yml`](config/agent_environments.yml).

## Load Testing

`bin/locust` runs [Locust](https://locust.io/) load tests against gobo via Docker, using
a patched fork ([p-datadog/locust](https://github.com/p-datadog/locust)) with UI fixes.
On first run it clones the fork and builds the Docker image automatically; subsequent runs
reuse the cached image.

```bash
bin/locust                              # Hit localhost:3000 (default)
bin/locust http://other-host:3000       # Hit a different host
```

The container uses `--network=host` so it shares the host's network stack — `localhost:3000`
reaches gobo directly without bridge networking or firewall rules. Use `-r` to rebuild the
Docker image after updating the fork.

The Locust web UI is at **http://localhost:8089** — set the number of users and spawn rate
there to start the test.

Endpoints hit (weight):
- `/` (3) — homepage
- `/debugger_test/stdlib_probe` (3) — exercises DI stdlib probe code
- `/help` (1)
- `/about` (1)

Wait time between requests is 10–50ms per user, so even a small user count generates
significant throughput. Useful for verifying that DI probes don't degrade performance
under load.

## License

This project is available under the MIT License. See [LICENSE.md](LICENSE.md) for details.

The base project ([rails_tutorial_sample_app_7th_ed](https://github.com/learnenough/rails_tutorial_sample_app_7th_ed)) is available jointly under the MIT License and the Beerware License.
