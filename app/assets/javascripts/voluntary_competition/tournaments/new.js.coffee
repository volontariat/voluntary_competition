$(document).ready ->
  $(document.body).on "change", "input[name='tournament[system_type]']", ->
    if $("input[name='tournament[system_type]']:checked").val() == '0'
      $('#tournament_third_place_playoff_wrapper').hide()
      $('#tournament_with_group_stage_wrapper').hide()
      $('#tournament_groups_count_wrapper').hide()
    else
      $('#tournament_third_place_playoff_wrapper').show()
      $('#tournament_with_group_stage_wrapper').show()

  $(document.body).on "change", "input[name='tournament[with_group_stage]']", ->
    if $("input[name='tournament[with_group_stage]']:checked").val() == '0' || $("input[name='tournament[with_group_stage]']:checked").val() == undefined
      $('#tournament_groups_count_wrapper').hide()
    else
      $('#tournament_groups_count_wrapper').show()