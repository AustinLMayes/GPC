# Building Onyx cues for a song

require 'onyx'

class Song
    attr_accessor :name, :num, :cuelist, :slide_refs, :current_slide, :presentation, :make_cuelist, :bpm, :meter

    START_NUM = 150

    def initialize(name, num, bpm, meter)
        @name = name
        @num = num
        @bpm = bpm
        @meter = meter
        name_exists = Onyx::Cuelist.from_name($client, @name)
        unless name_exists
            while num_exists = Onyx::Cuelist.find_one($client, vis_cue_list_id: Onyx::Cuelist.human_to_onyx_id(@num + START_NUM))
                @num += 10
            end
            @cuelist = Onyx::Cuelist.new.tap do |cuelist|
                cuelist.cue_list_name = @name
                cuelist.vis_cue_list_id = Onyx::Cuelist.human_to_onyx_id(@num + START_NUM)
                cuelist.default_release_time = 2500
            end
            @cuelist.save($client)
            @make_cuelist = true
        else
            @make_cuelist = false
            warn "Cuelist #{@name} already exists! Not making cues."
        end
        @slide_refs = {}
        @current_slide = 0
        cue { |c| c.set_name("Count") }
        add_slide_ref("Count")
    end

    def create
        cue { |c| c.set_name("Fade") }
        path = "/Users/austinmayes/Documents/ProPresSongs/#{@name}.txt"
        if File.exists?(path)
            warn "Slide file already exists! Not making slides."
            return
        end
        File.open(path, 'w') do |file|
            slide_refs.keys.each do |key|
                file.write "‎" + key.split(' ').map(&:capitalize).map(&:strip).join(' ') + "\n"
            end
        end
    end

    def add_slide_ref(name)
        slide = @current_slide += 1
        @slide_refs[name.downcase] = slide
    end

    def cue(&block)
        builder = CueBuilder.new(@bpm, @meter)
        block.call(builder)
        slide = get_slide_ref(builder.slide)
        return unless @make_cuelist
        cue = case builder.type
              when :go
                  @cuelist.add_go_cue($client, builder.name, comment: builder.comment, time: builder.time)
              when :wait
                  @cuelist.add_wait_cue($client, builder.name, builder.type_time, comment: builder.comment, time: builder.time)
              when :follow
                  @cuelist.add_follow_cue($client, builder.name, builder.type_time, comment: builder.comment, time: builder.time)
              else
                  raise "Unsupported cue type: #{builder.type}"
              end
        cue.add_macro("TRIGGER IntList 2243Q#{slide}") unless slide.nil?
        cue.save($client)
        info "Cue #{cue.cue_name} - #{cue.comment} created with time #{cue.fade_in}"
        if builder.mark?
            @cuelist.add_wait_cue($client, "--" + builder.name + " IN", builder.time, comment: builder.comment, time: builder.time).save($client)
            info "Added mark cue for #{builder.name} at #{builder.time} seconds"
        end
    end

    class CueBuilder
        attr_reader :name, :time, :comment, :slide, :bpm, :meter, :type, :type_time
        def initialize(bpm, meter)
            @bpm = bpm
            @meter = meter
            @time = 2.5
            @marked = false
            @type = :go
            @type_time = 0
        end

        def set_name(name)
            @name = name
            self
        end

        def set_comment(comment)
            @comment = comment
            self
        end

        def set_slide(type)
            case type
            when :name
                @slide = @name.gsub(/\d+/, '').strip
            when :name_comment
                @slide = @name.gsub(/\d+/, '').strip + (@comment.nil? ? "" : " " + @comment.strip)
            else
                @slide = type
            end
        end

        def set_time(val, scale = :sec)
            @time = case scale
                    when :sec
                        val
                    when :clicks
                        time_for_meter(val)
                    when :beats
                        val * 60.0 / @bpm
                    else
                        raise "Unsupported time scale: #{scale}"
                    end
            self
        end

        def mark
            @marked = true
            self
        end

        def mark?
            @marked
        end

        def wait(time)
            @type = :wait
            @type_time = time
            self
        end

        def follow(time)
            @type = :follow
            @type_time = time
            self
        end

        private

        def time_for_meter(clicks)
            meter = @meter.split('/')[1].to_i
            seconds_per_click = 60.0 / @bpm

            (if meter == 4
                seconds_per_click * clicks
            elsif meter == 8
                seconds_per_click * clicks / 2
            else
                raise "Unsupported meter note value: #{note_value}"
            end).round(2)
        end

        def name_or_comment(text)
            if @name.nil?
                @name = text
            else
                @comment = text
            end
            self
        end

        def self.song_sec_method(name)
            # automatically create methods for each section
            self.define_method(name) do |num = nil|
                name = name.to_s.split('_').map(&:capitalize).join('')
                @name = name + (num ? " #{num}" : "")
                self
            end
        end

        def self.song_sec_methods(*names)
            names.each { |name| song_sec_method(name) }
        end

        def self.song_dynamic_method(name)
            # automatically create methods for each dynamic
            self.define_method(name) do
                name_or_comment(name.to_s.split('_').map(&:capitalize).join(' '))
            end
        end

        def self.song_dynamic_methods(*names)
            names.each { |name| song_dynamic_method(name) }
        end

        song_sec_methods :intro, :verse, :pre_chorus, :chorus, :post_chorus, :bridge, :outro, :tag, :interlude, :vamp, :turnaround, :instrumental, :ending
        song_dynamic_methods :slowly_build, :build, :break, :breakdown, :all_in, :drums_in, :drums, :swell, :half_time, :double_time, :drive, :groove, :wash, :walk, :church, :hits

    end

    private

    def get_slide_ref(name)
        return nil if name.nil? || name.empty?
        name = name.downcase
        val = @slide_refs[name]
        if val.nil?
            name = name.strip
            val = @slide_refs[name]
        end
        add_slide_ref(name) if val.nil?
        val = @slide_refs[name]
        val
    end
end
