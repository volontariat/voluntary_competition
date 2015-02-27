$(document).ready ->
  $(document.body).on "change", "input[name='tournament[system_type]']", ->
    if $("input[name='tournament[system_type]']:checked").val() == '0'
      $('#tournament_third_place_playoff_wrapper').hide()
    else
      $('#tournament_third_place_playoff_wrapper').show()
