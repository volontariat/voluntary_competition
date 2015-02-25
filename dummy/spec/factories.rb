def r_str
  SecureRandom.hex(3)
end

def resource_has_many(resource, association_name)
  association = if resource.send(association_name).length > 0
    nil
  elsif association_name.to_s.classify.constantize.count > 0
    association_name.to_s.classify.constantize.last
  else
    Factory.create association_name.to_s.singularize.to_sym
  end
  
  resource.send(association_name).send('<<', association) if association
end

FactoryGirl.define do
  Voluntary::Test::RspecHelpers::Factories.code.call(self)
  
  factory :game do
    sequence(:name) { |n| "game #{n}#{r_str}" }
  end
  
  factory :exercise_type do
    sequence(:name) { |n| "exercise type #{n}#{r_str}" }
  end  
  
  factory :game_and_exercise_type do
    association :game
    association :exercise_type
  end
  
  factory :competitor do
    sequence(:name) { |n| "competitor #{n}#{r_str}" }
    association :game_and_exercise_type
    association :user
  end
  
  factory :tournament do
    association :game_and_exercise_type
    system_type 0
    sequence(:name) { |n| "competitor #{n}#{r_str}" }
    competitors_limit 3
    association :user
  end
  
  factory :tournament_season_participation do
    association :season
    association :competitor
  end
  
  factory :tournament_match do
  end
end