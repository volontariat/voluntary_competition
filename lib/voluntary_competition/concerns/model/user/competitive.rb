module VoluntaryCompetition
  module Concerns
    module Model
      module User
        module Competitive
          extend ActiveSupport::Concern
          
          included do
            has_many :competitors, dependent: :destroy
            has_many :tournaments, dependent: :destroy
            
            def join_tournament_season_with_competitors(season, competitor_ids)
              participation = TournamentSeasonParticipation.new
              user_competitor_ids = competitors.where(game_and_exercise_type_id: season.tournament.game_and_exercise_type_id).map(&:id)
              already_joined_competitor_ids = season.participations.where(competitor_id: user_competitor_ids).map(&:competitor_id)
              competitor_ids ||= []
              competitor_ids = competitor_ids.map(&:to_i).select{|id| user_competitor_ids.include?(id) }
              left_competitor_ids = already_joined_competitor_ids.select{|id| !competitor_ids.include?(id) }
              new_competitor_ids = competitor_ids.select{|id| !already_joined_competitor_ids.include?(id) }
              
              season.participations.where(competitor_id: left_competitor_ids).destroy_all if left_competitor_ids.any?
              
              if already_joined_competitor_ids.empty? && competitor_ids.none?
                participation.errors[:base] << I18n.t('participations.create.please_select_at_least_one_competitor')
              else
                participation.errors[:base] << I18n.t('tournament_seasons.general.no_more_competitors_needed') unless season.competitors_needed?
              end
              
              unless participation.errors.any?
                errors = season.create_participations_by_competitor_ids(new_competitor_ids, id)
                participation.errors[:base] += errors if errors.any?
              end
              
              participation
            end
          end
        end
      end
    end
  end
end