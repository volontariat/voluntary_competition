$(document).ready ->
  $(document.body).on "change", "select[name^=\"season_id\"]", ->
    this.form.submit()
