// Configure your import map in config/importmap.rb.
import Rails from "@rails/ujs"
import Turbolinks from "turbolinks"
import * as ActiveStorage from "@rails/activestorage"
import jQuery from "jquery"
import "bootstrap"

// Expose jQuery globals for the RJS responses in relationships/*.js.erb and
// the inline script in shared/_micropost_form.html.erb, which call $().
window.$ = jQuery
window.jQuery = jQuery

Rails.start()
Turbolinks.start()
ActiveStorage.start()
