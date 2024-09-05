# Ruby representation of a top-to-bottom service order pulled from Planning Center Online

require 'onyx'
require_relative 'pco/pco'
require_relative 'macros'
require_relative 'companion_page'

class Service
    attr_reader :cuelist, :cuelists, :songs, :cues, :page, :errors

    def initialize(name)
        name = name[0..-2] if name.end_with?("1")
        cue_list_name = "Service Order #{name.upcase}"
        @cuelist = Onyx::Cuelist.from_name($client, cue_list_name)
        $client.execute("DELETE FROM CueValuesV3 WHERE CueListID = #{@cuelist.cue_list_id}") unless @cuelist.nil? 
        @cuelist = Onyx::Cuelist.new.tap do |cuelist|
            cuelist.cue_list_name = cue_list_name
            cuelist.vis_cue_list_id = Onyx::Cuelist.next_available_vis_id($client, Onyx::Cuelist.human_to_onyx_id(14), Onyx::Cuelist.human_to_onyx_id(20))
            cuelist.cuelist_appearance = "#-16760223"
        end if @cuelist.nil?
        @cuelist.save($client)
        @cuelists = []
        @songs = []
        @cues = []
        @page = CompanionPage.new
    end

    # Load data from service.json
    def from_json(json)
        json.each do |item|
            macros_json = item[:macros]
            macros = []
            macros_json.each do |macro|
                if macro[:type] == "companion"
                    macros << trigger_companion(id: macro[:id], button_txt: macro[:button_txt], pp_item: macro[:pp_item] || -1)
                elsif macro[:type] == "select"
                    macros << trigger_cuelist(macro[:id], trigger: macro[:trigger] || false, song: macro[:song] || false, cue: macro[:cue] || 1)
                else
                    begin
                        macros << Macros.from_json(macro)
                    rescue => e
                        add_error("Error parsing macro: #{macro}")
                    end
                end
            end
            auto = item[:auto] == true
            if auto
                @cues << @cuelist.add_follow_cue($client, item[:name], item[:time], comment: item[:comment], macros: macros)
            else
                @cues << @cuelist.add_go_cue($client, item[:name], comment: item[:comment], macros: macros)
            end
        end
    end

    # Trigger a companion button from Onyx and add it to the exported page JSON
    def trigger_companion(id: nil, button_txt: nil, pp_item: -1)
        raise "Missing companion ID" if id.nil?
        raise "Missing companion button text" if button_txt.nil?
        if pp_item != -1
            @page.add_button(id, button_txt, item: pp_item)
        else
            @page.add_button(id, button_txt)
        end
        Macros.trigger(Macros::CueListIDs::COMPANION, cue: @page.button_index - 9)
    end

    # Trigger a cuelist by name or ID and add it to the order matrix
    def trigger_cuelist(cl_id, trigger: false, song: false, cue: 1)
        if cl_id == "none"
            return Macros.select("none", trigger: trigger)
        end
        cuelist = nil
        if cl_id.is_a?(Integer)
            cuelist = Onyx::Cuelist.from_id($client, cl_id)
        else
            cuelist = Onyx::Cuelist.from_name($client, cl_id)
        end
        if cuelist.nil?
            add_error("Cuelist not found: #{cl_id}")
            return Macros.select("none", trigger: trigger)
        end
        @songs << cuelist if song
        @cuelists << cuelist unless !@cuelists.empty? && @cuelists.last.cue_list_id == cuelist.cue_list_id
        Macros.select(cl_id, trigger: trigger, cue: cue)
    end

    def save_cues
        if has_error?
            raise "Cannot save cues because of errors #{errors.join(", ")}"
        end
        @cues.each do |cue|
            cue.save($client)
            info "Created cue #{cue.cue_name} with macros: #{cue.macros.join("\t")}"
        end
    end

    # Keep cue list directory up to date with new cuelists at the top
    def update_cuelist_directory(offset)
        info "Moving old cuelists to archive..."
        start_vis_id = Onyx::Cuelist.human_to_onyx_id(141 + (offset * 10))
        end_vis_id = start_vis_id + Onyx::Cuelist.human_to_onyx_id(20)
        Onyx::Cuelist.find_raw($client, "VisCueListID >= #{start_vis_id} AND VisCueListID < #{end_vis_id}").each do |cue|
            info "Moving #{cue.cue_list_name} to archive"
            cue.move_to_archive($client)
        end

        info "Moving songs to service slots in cuelist directory..."
        @songs.each_with_index do |song, i|
            info "Moving #{song.cue_list_name} to slot #{i+1}"
            song.vis_cue_list_id = start_vis_id + Onyx::Cuelist.human_to_onyx_id(i)
            song.save($client)
        end
    end

    # Update the playback buttons on the Sunday page
    def update_playback_buttons(offset)
        info "Moving cuelists to Sunday page #{offset}..."
        page = 1 + offset
        page = [1, page].max
        raise "Invalid page number: #{page}" if page > 6
        info "Page #{page}"
        Onyx::Matrix.delete($client, matrix_page: page)
        @cuelists.each_with_index do |cue, i|
            info "Moving #{cue.cue_list_name} to slot #{i+1} on page #{page}"
            matrix = Onyx::Matrix.new
            matrix.matrix_page = page
            matrix.matrix_pos_x = i + 1
            matrix.matrix_pos_y = -1
            matrix.matrix_cue_list_id = cue.cue_list_id
            matrix.save($client)
        end
    end

    # Save the companion page JSON to a file
    def save_companion_page(name)
        json = @page.to_json
        Dir.mkdir("companion") unless File.exists?("companion")
        File.open("companion/#{name}.companionconfig", 'w') do |file|
            file.write(json)
        end
    end

    def add_error(error)
        @errors ||= []
        @errors << error
    end

    def has_error?
        !@errors.nil? && @errors.length > 0
    end
end
