class Game < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  
  attr_accessible :name
end