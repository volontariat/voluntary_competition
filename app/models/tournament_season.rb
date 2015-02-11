class TournamentSeason < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  
  belongs_to :tournament
  
  has_many :participations, class_name: 'TournamentSeasonParticipation', foreign_key: 'season_id', dependent: :destroy
  has_many :accepted_participations, -> { where "tournament_season_participations.state = 'accepted'" }, class_name: 'TournamentSeasonParticipation', foreign_key: 'season_id'
  has_many :competitors, foreign_key: 'season_id', through: :accepted_participations
  has_many :rankings, class_name: 'TournamentSeasonRanking', foreign_key: 'season_id'
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
  
  def activate!
    initialize_rankings
    generate_matches
  end

  def consider_matches(working_matches)
    return if working_matches.none?
    
    competitor_ids = working_matches.map{|m| [m.home_competitor_id, m.away_competitor_id]}.flatten
    matchday = working_matches.first.matchday
    working_rankings = rankings.where(matchday: matchday, competitor_id: competitor_ids).index_by(&:competitor_id)
    
    working_matches.each do |match|
      working_rankings[match.home_competitor_id].consider_match(match)
      working_rankings[match.away_competitor_id].consider_match(match)
    end
    
    position = 1
    
    rankings.where(matchday: matchday).order('points DESC, goal_differential DESC, goals_scored DESC').each do |ranking|
      ranking.position = position
      ranking.calculate_trend
      ranking.save!
      
      position += 1
    end
    
    if rankings.where(matchday: matchday, played: false).none? && matchday + 1 <= matchdays
      increment!(:current_matchday) 
      
      competitors.each do |competitor|
        TournamentSeasonRanking.create_by_competitor(competitor.id, current_matchday, self)
      end
    end
  end
  
  private
    
  def initialize_rankings
    TournamentSeasonRanking.create_by_season(self)
  end
  
  def generate_matches
    matchdays, already_played_matchdays, already_played_competitor_ids = 0, {}, {}
    
    competitors.each do |competitor|
      already_played_matchdays[competitor.id] ||= []
      already_played_competitor_ids[competitor.id] ||= []
      competitor_ids = competitors.map(&:id).select{|id| id != competitor.id && !already_played_competitor_ids[competitor.id].include?(id)}
      
      competitor_ids.each do |other_competitor_id|
        already_played_matchdays[other_competitor_id] ||= []
        already_played_competitor_ids[other_competitor_id] ||= []
        i = 0
        
        begin
          i += 1
        end while already_played_matchdays[competitor.id].include?(i) || already_played_matchdays[other_competitor_id].include?(i)
        
        already_played_matchdays[competitor.id] << i
        already_played_matchdays[other_competitor_id] << i
        already_played_competitor_ids[competitor.id] << other_competitor_id
        already_played_competitor_ids[other_competitor_id] << competitor.id
        
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