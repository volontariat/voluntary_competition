window.VoluntaryCompetition or= {}; window.VoluntaryCompetition.Seasons or= {}

window.VoluntaryCompetition.Seasons.BracketView = class BracketView
  constructor: ->
    $(document.body).on "ajax:beforeSend", "#bracket_matches_form", ->
      $("#bracket_matches_spinner").show()