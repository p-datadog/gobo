// Configure your import map in config/importmap.rb.
import Rails from "@rails/ujs"
import { start as startActiveStorage } from "@rails/activestorage"
import "bootstrap"

// jQuery is loaded as a classic script in the layout (jquery/jquery.js)
// and sets window.$ / window.jQuery, used by the RJS responses in
// relationships/*.js.erb and the inline script in shared/_micropost_form.html.erb.

Rails.start()
startActiveStorage()
