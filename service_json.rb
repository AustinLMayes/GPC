# Creation tool of service.json

require 'onyx'
require_relative 'pco/pco'
require_relative 'macros'

class ServiceJSON
    attr_reader :current_cue_list, :last_cue_list, :current_section, :seen_sections, :section_index, :video_index, :video, :cues, :companion_index
    attr_accessor :pp_item_index

    def initialize
        @current_section = nil
        @seen_sections = []
        @section_index = 0
        @video_index = 0
        @video = false
        @cues = []
        @pp_item_index = 0
        @companion_index = 0
    end

    def trigger_companion(id: nil, button_txt: nil, pp_item: -1)
        id = id || Section.companion_id(@current_section,@section_index)
        button_txt = button_txt || Section.name(@current_section)
        @companion_index += 1
        {type: "companion", id: id, button_txt: button_txt, pp_item: pp_item}
    end

    def trigger_video
        res = [{type: "house", look: "video"}, trigger_companion(id: "prelim-vid", button_txt: "Video"), {type: "stage", look: "bo-med"}, trigger_cuelist(Macros::CueListIDs::PRELIM_VIDEO)]
        video(true)
        res
    end

    def trigger_cuelist(cl_id, song: false)
        video(false)
        @last_cue_list = @current_cue_list
        @current_cue_list = cl_id
        { type: "select", id: cl_id, trigger: true, song: song }
    end

    def add_cue(release_current: false, name:, comment: '', time: 0, auto: false, macros: [])
        if release_current && !@last_cue_list.nil?
            macros << {type: "release", id: @last_cue_list}
            @last_cue_list = nil
        end
        res = {name: name, comment: comment, macros: macros}
        res[:time] = time unless time == 0
        res[:auto] = auto if auto
        @cues << res
    end

    def set_section(section)
        @current_section = section
        @seen_sections << @current_section unless @seen_sections.include?(@current_section) 
        @section_index = 0
    end

    def handle_heading(item)
        set_section Section.from_heading(item["attributes"]["title"], @current_section)
    end

    def add_pre_experience
        set_section Section::PRE
        add_cue(name: "Pre-Experience", comment: "Pre-Experience Look", macros: [{type: "release", id: "25:9999"}, {type: "release", id: Macros::CueListIDs::DIMMERS_70}, trigger_cuelist(Macros::CueListIDs::IN_OUT), trigger_companion(id: "pre-x", button_txt: "PreX"), {type: "house", look: "pre"}, {type: "haze", output: "med"}])
        add_cue(name: "1 Minute Countdown", comment: "Blackout Stage + Lyrics", macros: [{type: "select", id: Macros::CueListIDs::IN_OUT, cue: 2, trigger: true}, trigger_companion(id: "1min", button_txt: "1MIN"), {type: "house", look: "opener"}, {type: "haze", output: "max"}])
    end

    def add_altar
        unless @seen_sections.include?(Section::ALTAR)
            add_cue(name: "Altar", comment: "Altar Look", macros: [{type: "select", id: Macros::CueListIDs::MESSAGE, cue: 2, trigger: true}, {type: "stage", look: "worship-slow"}, trigger_companion(id: "altar", button_txt: "Altar", pp_item: @pp_item_index += 1), {type: "house", look: "altar-worship"}])
        end
        set_section Section::ALTAR
    end

    def add_post_experience
        unless @seen_sections.include?(Section::POST)
            add_cue(name: "Post-Experience", comment: "Post-Experience Look", time: 0, macros: [{type: "select", id: Macros::CueListIDs::IN_OUT, trigger: true}, {type: "release", id: "140:9999"}, trigger_companion(id: "post-x", button_txt: "PostX"), {type: "house", look: "pre"}])
        end
        set_section Section::POST
        add_cue(name: "Cleanup", comment: "Cleanup Look", time: 0, macros: [{type: "trigger", id: Macros::CueListIDs::DIMMERS_70}, trigger_companion(id: "clear", button_txt: "CLEAR"), {type: "select", id: "none"}])
        add_cue(name: "Power Down", comment: "Power Down Look", time: 1, macros: [{type: "release", id: "25:9999"}, {type: "reset"}, {type: "release", id: "this"}], auto: true)
    end

    def in_video?
        @video
    end

    def video(video)
        @video = video
        @video_index += 1 if @video
    end

    def at_beginning_of_section?
        @section_index == 0 || (@current_section == Section::WORSHIP && @section_index == 1)
    end

    def increment_section_index
        @section_index += 1
    end

    def determine_house_level
        case @current_section
        when Section::OPENER
            {type: "house", look: "opener"}
        when Section::WORSHIP
            case @section_index
            when 0
                {type: "house", look: "2-1"}
            when 1
                {type: "house", look: "2-2"}
            when 2
                {type: "house", look: "2-3"}
            else
                {type: "house", look: "altar-hype"}
                warn "More than 3 worship songs - falling back to altar hype"
            end
        end
    end

    def determine_haze_level
        case @current_section
        when Section::OPENER
            {type: "haze", output: "med"}
        when Section::WORSHIP
            case @section_index
            when 0
                {type: "haze", output: "med"}
            when 1
                {type: "haze", output: "light"}
            else
                {type: "haze", output: "off"}
                warn "More than 2 worship songs - falling back to hazer off"
            end
        end
    end
end
