# Pin npm packages by running ./bin/importmap
# Pins resolve via Sprockets against node_modules (added to the asset path in
# config/initializers/assets.rb and populated by `yarn install`).

pin "application"
pin "bootstrap", to: "bootstrap/dist/js/bootstrap.esm.js"
pin "@popperjs/core", to: "@popperjs/core/lib/index.js"
pin "@rails/ujs", to: "@rails/ujs/app/assets/javascripts/rails-ujs.esm.js"
pin "@rails/activestorage", to: "@rails/activestorage/app/assets/javascripts/activestorage.esm.js"
