module VoluntaryCompetition
  module Navigation
    def self.code
      Proc.new do |navigation|
        navigation.items do |primary|
          primary.dom_class = 'nav'
          
          primary.item :exercise_types, I18n.t('exercise_types.index.title'), competition_exercise_types_path do |exercise_types|
            exercise_types.item :new, I18n.t('general.new'), new_competition_exercise_type_path if user_signed_in?
            
            unless (@exercise_type.new_record? rescue true)
              exercise_types.item :show, @exercise_type.name, competition_exercise_type_path(@exercise_type) do |exercise_type|
                if can? :destroy, @exercise_type
                  exercise_type.item :destroy, I18n.t('general.destroy'), competition_exercise_type_path(@exercise_type), method: :delete, confirm: I18n.t('general.questions.are_you_sure')
                end
      
                exercise_type.item :show, I18n.t('general.details'), "#{competition_exercise_type_path(@exercise_type)}#top"
                exercise_type.item :edit, I18n.t('general.edit'), edit_competition_exercise_type_path(@exercise_type) if can? :edit, @exercise_type
              end
            end
          end
          
          primary.item :tournaments, I18n.t('tournaments.index.title'), competition_tournaments_path do |tournaments|
            tournaments.item :new, I18n.t('general.new'), new_competition_tournament_path if user_signed_in?
            
            unless (@tournament.new_record? rescue true)
              tournaments.item :show, @tournament.name, competition_tournament_path(@tournament) do |tournament|
                if can? :destroy, @tournament
                  tournament.item :destroy, I18n.t('general.destroy'), competition_tournament_path(@tournament), method: :delete, confirm: I18n.t('general.questions.are_you_sure')
                end
      
                tournament.item :show, I18n.t('general.details'), "#{competition_tournament_path(@tournament)}#top"
                tournament.item :edit, I18n.t('general.edit'), edit_competition_tournament_path(@tournament) if can? :edit, @tournament
              end
            end
          end
          
          primary.item :competitors, I18n.t('competitors.index.title'), competition_competitors_path do |competitors|
            competitors.item :new, I18n.t('general.new'), new_competition_competitor_path if user_signed_in?
            
            unless (@competitor.new_record? rescue true)
              competitors.item :show, @competitor.name, competition_competitor_path(@competitor) do |competitor|
                if can? :destroy, @competitor
                  competitor.item :destroy, I18n.t('general.destroy'), competition_competitor_path(@competitor), method: :delete, confirm: I18n.t('general.questions.are_you_sure')
                end
      
                competitor.item :show, I18n.t('general.details'), "#{competition_competitor_path(@competitor)}#top"
                competitor.item :edit, I18n.t('general.edit'), edit_competition_competitor_path(@competitor) if can? :edit, @competitor
              end
            end
          end
          
          instance_exec primary, ::Voluntary::Navigation::Base.menu_options(:authentication), &::Voluntary::Navigation.menu_code(:authentication)
        end
      end
    end
  end
end
    