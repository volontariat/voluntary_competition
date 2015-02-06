module VoluntaryCompetition
  module Concerns
    module Model
      module User
        module Competitive
          extend ActiveSupport::Concern
          
          included do
            has_many :competitors, dependent: :destroy
          end
        end
      end
    end
  end
end