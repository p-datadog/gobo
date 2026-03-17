# Ruby Live Debugger Demo

A Ruby live debugger demo based on the [Rails Tutorial sample app](https://github.com/learnenough/rails_tutorial_sample_app_7th_ed).

## License

This project is available under the MIT License. See [LICENSE.md](LICENSE.md) for details.

The base project ([rails_tutorial_sample_app_7th_ed](https://github.com/learnenough/rails_tutorial_sample_app_7th_ed)) is available jointly under the MIT License and the Beerware License.

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

## DD_TRACER Configuration

The `DD_TRACER` environment variable controls which version of dd-trace-rb to use:

- **Unset or empty** - Uses the latest release from RubyGems
  ```bash
  export DD_TRACER=""
  ```

- **Version constraint** - Uses the specified version or range
  ```bash
  export DD_TRACER="~> 1.0.0"
  export DD_TRACER="1.15.0"
  ```

- **Git URL** - Uses the specified branch, tag, or commit from a git repository
  ```bash
  export DD_TRACER="git+https://github.com/DataDog/dd-trace-rb@branch-name"
  export DD_TRACER="git+https://github.com/DataDog/dd-trace-rb@abc1234"
  ```

- **Absolute path** - Uses a local copy from the filesystem
  ```bash
  export DD_TRACER="/home/user/dd-trace-rb"
  ```

