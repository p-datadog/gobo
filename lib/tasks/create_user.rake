task create_user: :environment do
  user = User.create!(name: 'Admin', email: 'admin@example.com', password: 'admin', password_confirmation: 'admin', activated: true, activated_at: Time.zone.now)
  user.microposts.create!(content: 'This is a demo post')
  puts "Admin user created successfully: #{user.email}"
end
