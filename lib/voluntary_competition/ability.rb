module VoluntaryCompetition
  class Ability
    def self.after_initialize
      Proc.new do |ability, user, options|
        ability.can :read, [
          Competitor
        ]
        
        if user.present?
          ability.can(:restful_actions, Competitor) {|competitor| competitor.new_record? || competitor.user_id == user.id }
        end
      end
    end
  end
end
