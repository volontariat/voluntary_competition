$(document).ready ->
  $(document.body).on "keyup.autocomplete", "#tournament_exercise_type_name", ->  
    $(this).autocomplete
      source: $(this).data('source')
      minLength: 2
      search: (event, ui) ->
        $('#tournament_exercise_type_id').val(null)
      select: (event, ui) ->
        $(this).val(ui.item.value)
        $('#tournament_exercise_type_id').val(ui.item.id)
        
        return false;
        
  $(document.body).on "keyup.autocomplete", "#tournament_game_name", ->  
    $(this).autocomplete
      source: $(this).data('source')
      minLength: 2
      search: (event, ui) ->
        $('#tournament_game_id').val(null)
      select: (event, ui) ->
        $(this).val(ui.item.value)
        $('#tournament_game_id').val(ui.item.id)
        
        return false;