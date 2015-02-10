class TournamentSeason < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  
  belongs_to :tournament
  
  has_many :participations, class_name: 'TournamentSeasonParticipation', foreign_key: 'season_id', dependent: :destroy
  has_many :accepted_participations, -> { where "tournament_season_participations.state = 'accepted'" }, class_name: 'TournamentSeasonParticipation', foreign_key: 'season_id'
  has_many :competitors, foreign_key: 'season_id', through: :accepted_participations
  has_many :matches, class_name: 'TournamentMatch', foreign_key: 'season_id'
  
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
  
  def generate_matches
    matchdays = 0
    
    competitors.each do |competitor|
      already_played_matchdays, already_played_competitor_ids = [], []
      
      matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: competitor.id).map do |match|
        already_played_matchdays << match.matchday 
        already_played_competitor_id = match.home_competitor_id == competitor.id ? match.away_competitor_id : match.home_competitor_id
        already_played_competitor_ids << already_played_competitor_id
      end
      competitor_ids = competitors.select('competitors.id').where('competitors.id NOT IN(?)', [competitor.id] + already_played_competitor_ids).map(&:id).shuffle
      i = 0
      
      competitor_ids.each do |other_competitor_id|
        already_played_matchdays_of_other_competitor = matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: other_competitor_id).map(&:matchday)
        
        begin
          if i == 0 || already_played_matchdays.include?(i) || already_played_matchdays_of_other_competitor.include?(i)
            i += 1
          end
        end while already_played_matchdays.include?(i) || already_played_matchdays_of_other_competitor.include?(i)
         
        already_played_matchdays << i
        home_competitor_id, away_competitor_id = i % 2 == 0 ? [competitor.id, other_competitor_id] : [other_competitor_id, competitor.id]
        
        matches.create!(
          matchday: i, home_competitor_id: home_competitor_id, away_competitor_id: away_competitor_id, date: Time.now
        )
        
        matchdays = i if i > matchdays
      end
    end
    
    tournament.update_attribute(:matchdays_per_season, matchdays)
    self.matchdays = matchdays; self.current_matchday = 1; save!
  end
end