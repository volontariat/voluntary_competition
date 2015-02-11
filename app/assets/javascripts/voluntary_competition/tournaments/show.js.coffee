$(document).ready ->
  $(document.body).on "change", "select[name^=\"season_id\"]", ->
    this.form.submit()

  $(document.body).on "change", "select[name^=\"matchday\"]", ->
    this.form.submit()

  $(document.body).on "ajax:beforeSend", ".change_state_of_season_participation_link", ->
    $(this).find('.ajax_spinner').show()
    
  $('.tournament_show_tabs').on 'tabsload', (event, ui) ->
    $('.datetime_picker').datetimepicker()

  $(document.body).on "ajax:beforeSend", "#matches_form", ->
    $("#matches_spinner").show()