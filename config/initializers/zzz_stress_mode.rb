if ENV['STRESS_MODE'] == 'true'
  Rails.application.config.after_initialize do
    Rails.application.eager_load!
  end
end
