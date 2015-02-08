# -*- encoding : utf-8 -*-
ActiveRecord::Base.logger = Logger.new(STDOUT)

delivery_method_was = ActionMailer::Base.delivery_method
ActionMailer::Base.delivery_method = :test

=begin
db_seed = VolontariatSeed.new
db_seed.create_fixtures
=end

user = User.where(name: 'User').first
tournament = user.tournaments.create!(name: 'Fußball-Bundesliga der Männer', first_season_name: '2014/2015', competitors_limit: 3)
tournament.seasons.create!(name: '2015/2016')

4.times do |i|
  user.competitors.create!(name: "Player #{(i + 1)}")
end

puts "Done."

ActionMailer::Base.delivery_method = delivery_method_was
