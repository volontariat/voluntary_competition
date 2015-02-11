module VoluntaryCompetition
  class Ability
    def self.after_initialize
      Proc.new do |ability, user, options|
        ability.can :read, [
          Game, ExerciseType, GameAndExerciseType, Competitor, Tournament, TournamentSeason, TournamentSeasonParticipation, TournamentMatch
        ]
        
        if user.present?
          ability.can(:create, Game)
          ability.can(:create, ExerciseType)
          ability.can(:create, GameAndExerciseType)
          ability.can(:restful_actions, Competitor) {|competitor| competitor.new_record? || competitor.user_id == user.id }
          ability.can(:restful_actions, Tournament) {|tournament| tournament.new_record? || tournament.user_id == user.id }
          ability.can(:restful_actions, TournamentSeason) {|season| season.new_record? || season.tournament.user_id == user.id }
          ability.can(:restful_actions, TournamentSeasonParticipation) {|season_participation| season_participation.new_record? || season_participation.user_id == user.id }
          ability.can([:accept, :deny], TournamentSeasonParticipation) {|season_participation| season_participation.season.tournament.user_id == user.id }
          ability.can([:restful_actions, :updates], TournamentMatch) {|match| match.season.tournament.user_id == user.id }
        end
      end
    end
  end
end
