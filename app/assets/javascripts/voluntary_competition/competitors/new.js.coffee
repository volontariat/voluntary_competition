$(document).ready ->
  $(document.body).on "keyup.autocomplete", "#competitor_exercise_type_name", ->  
    $(this).autocomplete
      source: $(this).data('source')
      minLength: 2
      search: (event, ui) ->
        $('#competitor_exercise_type_id').val(null)
      select: (event, ui) ->
        $(this).val(ui.item.value)
        $('#competitor_exercise_type_id').val(ui.item.id)
        
        return false;
        
  $(document.body).on "keyup.autocomplete", "#competitor_game_name", ->  
    $(this).autocomplete
      source: $(this).data('source')
      minLength: 2
      search: (event, ui) ->
        $('#competitor_game_id').val(null)
      select: (event, ui) ->
        $(this).val(ui.item.value)
        $('#competitor_game_id').val(ui.item.id)
        
        return false;