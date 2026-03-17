module Helpers
  # Returns true if a test user is logged in (for model/unit specs using session)
  def is_logged_in?
    !session[:user_id].nil?
  end

  # Log in as a particular user via the sessions controller (for request specs)
  def log_in_as(user, password: 'password', remember_me: '1')
    post login_path, params: { session: { email: user.email,
                                          password: password,
                                          remember_me: remember_me } }
  end
end
