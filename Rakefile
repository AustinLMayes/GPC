# Mega tools for automating the conversion of Planning Center plans to Onyx cue stacks

require 'tiny_tds'
require 'common'
require 'onyx'
require 'pro_pres_api'
require_relative 'service_json'
require_relative 'service'
require_relative 'pco/pco'
require_relative 'song'
require 'ruby-rtf'

$client = TinyTds::Client.new username: 'sa', password: 'VeryStr0ngP@ssw0rd', host: 'localhost'
$client.execute("USE ShowData").do

def load_show
    backup_loc = '/var/opt/mssql/Show'
    new_loc = '/var/opt/mssql/onyx'

    # Get the list of files needed to be moved
    files = $client.execute("RESTORE FILELISTONLY FROM DISK = '#{backup_loc}'")

    # Move the files when doing the restore
    moves = []
    dbs = []
    files.each do |file|
        name_without_path = file['PhysicalName'].split('\\').last
        moves << "MOVE '#{file['LogicalName']}' TO '#{new_loc}/#{name_without_path}'"
        dbs << file['LogicalName']
    end

    $client.execute("USE master").do
    $client.execute("DROP DATABASE IF EXISTS ShowData").do
    
    dbs.each do |db|
        `touch /Users/austinmayes/Documents/sql-server/onyx/#{db.gsub('_','')}.mdf`
        `touch /Users/austinmayes/Documents/sql-server/onyx/#{db.gsub('_','')}.ldf`
    end
    sleep 3
    $client.execute("RESTORE DATABASE ShowData FROM DISK = '#{backup_loc}' WITH REPLACE,#{moves.join(',')}").do
end

desc "Load show data from OnyxShow file"
task :load_show do
    path = '/Users/austinmayes/Documents/sql-server/GPC Main.OnyxShow'
    info "Unzipping #{path}"
    system("rm", "/Users/austinmayes/Documents/sql-server/Show")
    system("unzip", path, "-d", "/Users/austinmayes/Documents/sql-server") or raise "Failed to unzip #{path}"
    load_show
end

desc "Make load script"
task :save_show do
    script = MSSQL.data_replace_script($client,["CueListsV3","CueValuesV3","MatrixV2","PlayBacksV3","AnalFaders"],'ShowData', sequences: ["SeqCueListId"])
    File.open('/Users/austinmayes/Documents/sql-server/load.sql','w') do |f|
        f.write(script)
    end
end

def parse_songs(file)
    # eval the file and get the array result
    eval(File.read(file))
end

desc "Load songs from file"
task :load_songs do
    songs = parse_songs('/Users/austinmayes/Projects/Ruby/GPC/cues.rb')
    songs.each(&:create)
end

@hold_at_cur_index = false

@char = "A"

def handle_song(item)
    tag = !item["attributes"]["description"].nil? && item["attributes"]["description"].downcase.include?("tag")
    if tag
        info "Skipping tag for #{item["attributes"]["title"]}"
        return
    end
    if $use_generic
        @char = (@char.ord-1).chr if item["attributes"]["title"].downcase.include?("reprise") && @char != "A"
        song_name = "Generic Song #{@char}"
        @char = @char.next
    else
        song_id = item["relationships"]["song"]["data"]["id"]
        song_info = PCO.get_song_info(song_id, item["relationships"]["arrangement"]["data"]["id"])
        song_name = song_info[:title] + " - " + song_info[:author]
    end
    macros = []
    macros << {type: "stage", look: "worship-med"} if @service.at_beginning_of_section? || @service.in_video?
    macros << @service.trigger_cuelist(song_name, song: true)
    item = @hold_at_cur_index ? @service.pp_item_index : @service.pp_item_index += 1
    @hold_at_cur_index = false
    macros << @service.trigger_companion(pp_item: item)
    house_macro = @service.determine_house_level
    haze_macro = @service.determine_haze_level
    macros << house_macro unless house_macro.nil?
    macros << haze_macro unless haze_macro.nil?
    name_short = song_name.split(" - ")[0]
    @service.add_cue(release_current: true, name: name_short, comment: "Song: #{song_name}", time: 0, macros: macros)
    @service.increment_section_index
end

def handle_generic(item)
    if item["attributes"]["title"].downcase.include?("worship song") && $use_generic
        handle_song(item)
        return
    end
    to_video = item["attributes"]["title"].downcase.include?("video")
    macros = []
    release_current = ((@service.at_beginning_of_section? && @service.current_section != Section::WORSHIP) || (to_video != @service.in_video?))
    case @service.current_section
    when Section::PRELIM, Section::PRE
        if @service.at_beginning_of_section? || (@service.in_video? && !to_video)
            macros << @service.trigger_cuelist(Macros::CueListIDs::PRELIM)
            macros << {type: "house", look: "prelim"}
            macros << {type: "stage", look: "center-med"}
            macros << @service.trigger_companion
            macros << {type: "haze", output: "light"}
        end
        @service.increment_section_index
    when Section::WORSHIP
        if @service.at_beginning_of_section?
            macros << {type: "select", id: Macros::CueListIDs::PRELIM, cue: 2, trigger: true}
            house_macro = @service.determine_house_level
            macros << house_macro unless house_macro.nil?
            macros << {type: "haze", output: "max"}
            macros << @service.trigger_companion(id: "prelim-ctw", button_txt: "CTW", pp_item: @service.pp_item_index += 1)
            @hold_at_cur_index = true
        else
            @service.increment_section_index
            warn "Found item in worship section that is not a song! #{item['attributes']['title']}"
        end
    when Section::MESSAGE
        if @service.at_beginning_of_section? || (@service.in_video? && !to_video)
            macros << @service.trigger_cuelist(Macros::CueListIDs::MESSAGE)
            macros << {type: "house", look: "preach"}
            macros << {type: "stage", look: "message"}
            macros << {type: "haze", output: "off"}
            macros << @service.trigger_companion
        end
        @service.increment_section_index
    when Section::PRAYER
        if @service.at_beginning_of_section?
            personal = false
            id = Macros::CueListIDs::PRELIM_PG
            if item["attributes"]["title"].downcase.include?("personal")
                id = "Personal Prayer Time"
                personal = true
            end
            macros << @service.trigger_cuelist(id)
            macros << {type: "house", look: personal ? "2-2" : "prelim"}
            macros << {type: "stage", look: personal ? "bo-med" : "center-med"}
            macros << {type: "haze", output: "off"}
            macros << @service.trigger_companion(id: personal ? "prelim-vid" : "prelim")
        end
    else
        raise "Unknown section #{@service.current_section}"
    end
    if !@service.in_video? && to_video
        macros += @service.trigger_video
    end
    if macros.empty?
        warn "No macros for #{item["attributes"]["title"]}"
    else
        @service.add_cue(release_current: release_current, name: item["attributes"]["title"].strip, comment: Section.name(@service.current_section) + ": #{item["attributes"]["title"]}", time: 0, macros: macros)
    end
end

desc "Create service order JSON file from PCO"
task :create_service do |task, args|
    service = {}
    type_counts = {}
    args.extras.each do |arg|
        name = arg.split(":")[0]
        generic = arg.split(":")[1] == "gen"
        type_counts[name] = type_counts[name].nil? ? 1 : type_counts[name] + 1
        offset = type_counts[name]
        service[name + offset.to_s] = create_service(name, generic, offset)
    end
    File.open("service.json", "w") do |f|
        f.write(JSON.pretty_generate(service))
    end
end

def create_service(name, generic, offset)
    name = case name
    when "am"
        "Sunday AM Service"
    when "pm"
        "Sunday PM Service"
    when "wed"
        "Wednesday Service"
    when "spec", "special"
        "Special Events"
    else
        raise "Unknown service type #{search}"
    end
    $use_generic = generic
    type = PCO.find_service_type_by_name(name)
    next_plan = PCO.get_plan(type["id"])[offset - 1]
    raise "No plan found for #{name}" if next_plan.nil?
    @service = ServiceJSON.new()
    @service.add_pre_experience
    PCO.act_on_items(next_plan, method(:handle_song), ->(item) { @service.handle_heading(item) }, method(:handle_generic))
    @service.add_altar
    @service.add_post_experience
    @service.cues
end

desc "Import service order JSON file"
task :import_service do
    json = JSON.parse(File.read("service.json"))
    json.each do |id, serv|
        serv.each do |cue|
            cue.deep_symbolize_keys!
        end
    end
    offset = 0
    FileUtils.rm_rf("companion")
    services = []
    json.each do |id, serv|
        info "Importing #{id}..."
        service = Service.new(id)
        service.from_json(serv)
        services << {id: id, service: service, offset: offset}
        offset += 1
    end
    services.each do |entry|
        service = entry[:service]
        if service.has_error?
            error "Cannot import service because of errors #{service.errors.join(", ")}"
        end
    end
    services.each do |entry|
        id = entry[:id]
        service = entry[:service]
        offset = entry[:offset]
        service.save_cues
        service.update_cuelist_directory(offset)
        service.update_playback_buttons(offset)
        service.save_companion_page(id)
    end

    start_vis_id = Onyx::Cuelist.human_to_onyx_id(301)
    lists = []
    Onyx::Cuelist.find_raw($client, "VisCueListID >= #{start_vis_id}", order: "CueListName").each do |cue|
        lists << cue
    end
    info "Organizing archive alphabetically..."
    lists.each_with_index do |cue, i|
        cue.vis_cue_list_id = start_vis_id + Onyx::Cuelist.human_to_onyx_id(i)
        cue.save($client)
    end

    info "Done!"
end
