SimpleNavigation::Configuration.run do |navigation|
  instance_exec navigation, &VoluntaryCompetition::Navigation.code
end