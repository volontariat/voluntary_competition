class TournamentSeason < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  
  belongs_to :tournament
  
  has_many :participations, class_name: 'SeasonParticipation', foreign_key: 'season_id', dependent: :destroy
  
  validates :tournament_id, presence: true
  
  attr_accessible :name
  
  def no_competitors_needed?(new_count, options = {})
    competitors_limit = options[:competitors_limit]
    new_and_already_joined_competitors_count = options[:new_and_already_joined_competitors_count]
    already_joined_competitors_count = options[:already_joined_competitors_count]
    competitors_limit ||= tournament.competitors_limit
    
    accepted_participations_count = participations.accepted.count
    needed_competitors_count = competitors_limit - accepted_participations_count
    
    if needed_competitors_count > 0
      false
    elsif new_and_already_joined_competitors_count.blank?
      I18n.t('tournament_seasons.general.no_more_competitors_needed')
    else
      I18n.t(
        'tournament_seasons.general.competitors_needed_from_selected_competitors', 
        needed_competitors_count: needed_competitors_count + already_joined_competitors_count, selected_competitors_count: new_and_already_joined_competitors_count
      )
    end
  end
  
  def create_participations_by_competitor_ids(competitor_ids, user_id)
    working_errors = []
    
    competitor_ids.each do |competitor_id|
      season_participation = participations.new
      season_participation.competitor_id = competitor_id
      season_participation.user_id = user_id
      season_participation.save
      
      unless season_participation.persisted?
        working_errors = season_participation.errors.full_messages.join('. ')
        
        break
      end
    end
    
    working_errors
  end
end