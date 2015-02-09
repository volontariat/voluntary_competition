class ExerciseType < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base

  validates :name, presence: true, uniqueness: true
  
  attr_accessible :name
end