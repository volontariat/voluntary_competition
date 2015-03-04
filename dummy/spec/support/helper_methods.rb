require 'fileutils'

def matches_factory(hash)
  matches, match_id = {}, 1
  
  hash.each do |of_winners_bracket, of_winners_bracket_matches|
    matches[of_winners_bracket] ||= {}
    
    of_winners_bracket_matches.each do |round, round_matches|
      matches[of_winners_bracket][round] ||= {}
      matchdays, competitor_ids = round_matches
      
      matchdays.each_with_index do |matchday, matchday_index|
        matches[of_winners_bracket][round][matchday] ||= []
        
        competitors_offset = 0
        
        begin
          match_competitors = competitor_ids[competitors_offset..(competitors_offset + 1)]
          match_data = if matchday_index == 0
            [match_competitors[0], match_competitors[1], 1, 0]
          else
            [match_competitors[1], match_competitors[0], 0, 1]
          end 
          
          matches[of_winners_bracket][round][matchday] << match_factory(
            id: match_id, home_competitor_id: match_data[0], away_competitor_id: match_data[1], 
            home_goals: match_data[2], away_goals: match_data[3]
          )
          match_id += 1
          competitors_offset += 2
        end while competitor_ids[competitors_offset..(competitors_offset + 1)].length == 2
      end
    end
  end
  
  matches
end

def match_factory(attributes)
  FactoryGirl.build(
    :tournament_match, attributes.merge(
      home_competitor: FactoryGirl.build(:competitor, id: attributes[:home_competitor_id], name: "P#{attributes[:home_competitor_id]}"),
      away_competitor: FactoryGirl.build(:competitor, id: attributes[:away_competitor_id], name: "P#{attributes[:away_competitor_id]}")
    )
  )
end

def compare_texts(got_string, expected_fixture_path)
  if preview
    absolute_path = File.join(File.dirname(__FILE__), "../fixtures/#{expected_fixture_path.split('/')[0..-2].join('/')}")
    FileUtils::mkdir_p absolute_path
    File.open("#{absolute_path}/#{expected_fixture_path.split('/')[-1]}", 'w') { |file| file.write(got_string) }
    puts "#{expected_fixture_path} created."
  else
    expect(strip_text(got_string)).to be == strip_text(load_fixture(expected_fixture_path))
  end
end

def strip_text(text, remove_empty_lines = true)
  text = text.strip.split("\n").map(&:strip)
  
  text.delete_if{|line| line == '' } if remove_empty_lines
  
  text.join("")
end

def load_fixture(path)
  path = File.join(File.dirname(__FILE__), "../fixtures/#{path}")
  File.open(path).read
end

def load_ruby_fixture(path)
  eval(load_fixture(path))
end