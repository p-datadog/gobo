# Ruby Live Debugger Demo

A Ruby live debugger demo based on the [Rails Tutorial sample app](https://github.com/learnenough/rails_tutorial_sample_app_7th_ed).

## Getting started

To get started with the app, first follow the setup steps in [Section 1.1 Up and running](https://www.railstutorial.org/book#sec-up_and_running).

Next, clone the repo and `cd` into the directory:

```
$ git clone https://github.com/mhartl/sample_app_6th_ed.git
$ cd sample_app_6th_ed
```

Also make sure you’re using a compatible version of Node.js:

```
$ nvm install 16.13.0
$ node -v
v16.13.0
```

Then install the needed packages (while skipping any Ruby gems needed only in production):

```
$ yarn add jquery@3.5.1 bootstrap@3.4.1
$ gem install bundler -v 2.2.17
$ bundle _2.2.17_ config set --local without 'production'
$ bundle _2.2.17_ install
```

Next, migrate the database:

```
$ rails db:migrate
```

Finally, run the test suite to verify that everything is working correctly:

```
$ rails test
```

If the test suite passes, you’ll be ready to seed the database with sample users and run the app in a local server:

```
$ rails db:seed
$ rails server
```

Follow the instructions in [Section 1.2.2 `rails server`](https://www.railstutorial.org/book#sec-rails_server) to view the app. You can then register a new user or log in as the sample administrative user with the email `example@railstutorial.org` and password `foobar`.

## DD_ENV Configuration

`DD_ENV` is defaulted to `developmestuction` because Dynamic Instrumentation requires an environment to be set. Without it, DI probes will not be delivered to the application. You can override this by passing `-e <env>` to `bin/run` or by setting the `DD_ENV` environment variable directly.

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

## License

This project is available under the MIT License. See [LICENSE.md](LICENSE.md) for details.

The base project ([rails_tutorial_sample_app_7th_ed](https://github.com/learnenough/rails_tutorial_sample_app_7th_ed)) is available jointly under the MIT License and the Beerware License.
