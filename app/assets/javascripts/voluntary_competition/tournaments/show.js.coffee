$(document).ready ->
  $(document.body).on "change", "select[name^=\"season_id\"]", ->
    this.form.submit()

  $(document.body).on "ajax:beforeSend", ".change_state_of_season_participation_link", ->
    $(this).find('.ajax_spinner').show()