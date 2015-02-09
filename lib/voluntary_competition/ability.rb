module VoluntaryCompetition
  class Ability
    def self.after_initialize
      Proc.new do |ability, user, options|
        ability.can :read, [
          ExerciseType, Competitor, Tournament, TournamentSeason, SeasonParticipation
        ]
        
        if user.present?
          ability.can(:create, ExerciseType)
          ability.can(:restful_actions, Competitor) {|competitor| competitor.new_record? || competitor.user_id == user.id }
          ability.can(:restful_actions, Tournament) {|tournament| tournament.new_record? || tournament.user_id == user.id }
          ability.can(:restful_actions, TournamentSeason) {|season| season.new_record? || season.tournament.user_id == user.id }
          ability.can(:restful_actions, SeasonParticipation) {|season_participation| season_participation.new_record? || season_participation.user_id == user.id }
          ability.can([:accept, :deny], SeasonParticipation) {|season_participation| season_participation.season.tournament.user_id == user.id }
        end
      end
    end
  end
end
