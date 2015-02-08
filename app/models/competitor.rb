class Competitor < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  
  belongs_to :user
  
  has_many :season_participations, dependent: :destroy
  
  validates :user_id, presence: true
  validates :name, presence: true, uniqueness: { scope: :user_id }
  
  attr_accessible :name
end