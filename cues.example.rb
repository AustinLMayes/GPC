s1 = Song.new("Test", 1, 120, "4/4")
s1.cue { |cue| cue.verse(1).breakdown.set_time(4, :beats) }
s1.cue { |cue| cue.chorus.set_time(8, :clicks).mark }

[s1]
