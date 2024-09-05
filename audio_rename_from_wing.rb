# Rename audio files based on a Behringer Wing snapshot file

require 'common'
require 'json'

SNAP_PATH = ARGV[0]
raise "No snapshot path provided" if SNAP_PATH.nil?
raise "Snapshot file does not exist" unless File.exists?(SNAP_PATH)
AUDIO_PATH = ARGV[1]
raise "No audio path provided" if AUDIO_PATH.nil?
raise "Audio path does not exist" unless File.exists?(AUDIO_PATH)

@seen_names = []

def rename_audio_files
    Dir.chdir(AUDIO_PATH) do
        Dir.glob("*.wav").each do |file|
            new_name = determine_file_name(file)
            # remove first -1 from name
            new_name = new_name.gsub("-1-", "-")
            new_name = new_name + "-2" if @seen_names.include?(new_name)
            @seen_names << new_name
            group = get_group(new_name).to_s
            FileUtils.mkdir_p(group)
            FileUtils.mv(file, "#{group}/#{new_name}")
            puts "Renamed #{file} to #{new_name} in #{group}"
        end
    end
end

@name_translations = {}

@groups = {}

def determine_file_name(file)
    @name_translations.each do |old_name, new_name|
        file = file.gsub(old_name, new_name) if file.include?(old_name)
    end
    file
end

snap_data = JSON.parse(File.read(SNAP_PATH))

snap_data["ae_data"]["io"]["in"].each do |group, inputs|
    next unless group == "LCL" || group == "A" || group == "B"
    group = "AES50-#{group}" if group == "A" || group == "B"
    inputs.each do |name, data|
        number = name
        number = "0#{number}" if number.to_i < 10
        next if data["name"].nil? || data["name"].strip.empty?
        in_name = data["name"].strip.gsub(" ", "-")
        if data['mode'] == 'ST'
            side = number.to_i % 2 == 0 ? "R" : "L"
            in_name = "#{in_name}-#{side}"
        end
        in_name.upcase!
        @name_translations["#{group}-#{number}"] = in_name
    end
end

def add_dante_translation(device, input, translation, group)
    @name_translations["D-#{device}-#{input}"] = translation
    group = group.to_sym
    @groups[group] = [] unless @groups.key?(group)
    @groups[group] << translation
end

# TODO: Parse Dante Device XML file to get device names instead of hardcoding

# CG
add_dante_translation("CG1", "01", "CG1-PC-L", "PB")
add_dante_translation("CG1", "02", "CG1-PC-R", "PB")
add_dante_translation("CG1", "03", "CG1-PROP-L", "PB")
add_dante_translation("CG1", "04", "CG1-PROP-R", "PB")
add_dante_translation("CG2", "01", "CG2-PROP-L", "PB")
add_dante_translation("CG2", "02", "CG2-PROP-R", "PB")
add_dante_translation("CG2", "03", "CG2-TB", "COMM")

# Shure
# 4 mics per device - BGV1-6, WL, MC, LAV1-2, SPARES
4.times do |i|
    add_dante_translation("SHURE1", "0#{i+1}", "BGV-0#{i+1}", "VOX")
end
add_dante_translation("SHURE2", "01", "BGV-05", "VOX")
add_dante_translation("SHURE2", "02", "BGV-06", "VOX")
add_dante_translation("SHURE2", "03", "WL", "VOX")
add_dante_translation("SHURE2", "04", "MC", "SPK")
add_dante_translation("SHURE3", "01", "LAV-01", "SPK")
add_dante_translation("SHURE3", "02", "LAV-02", "SPK")

# ableton
add_dante_translation("ABLETON", "01", "TX-CLICK", "TRAX")
add_dante_translation("ABLETON", "02", "TX-BASS", "TRAX")
add_dante_translation("ABLETON", "03", "TX-PERC-L", "TRAX")
add_dante_translation("ABLETON", "04", "TX-PERC-R", "TRAX")
add_dante_translation("ABLETON", "05", "TX-AG-L", "TRAX")
add_dante_translation("ABLETON", "06", "TX-AG-R", "TRAX")
add_dante_translation("ABLETON", "07", "TX-EG-L", "TRAX")
add_dante_translation("ABLETON", "08", "TX-EG-R", "TRAX")
add_dante_translation("ABLETON", "09", "TX-KEYS-L", "TRAX")
add_dante_translation("ABLETON", "10", "TX-KEYS-R", "TRAX")
add_dante_translation("ABLETON", "11", "TX-VOX-L", "TRAX")
add_dante_translation("ABLETON", "12", "TX-VOX-R", "TRAX")
add_dante_translation("ABLETON", "13", "TX-MUSIC-L", "TRAX")
add_dante_translation("ABLETON", "14", "TX-MUSIC-R", "TRAX")

def get_group(name)
    @groups.each do |group, inputs|
        inputs.each do |input|
            return group if name.include?(input)
        end
    end
    raise "No group found for #{name}"
end

def merge_groups(hash)
    hash.each do |group, inputs|
        @groups[group] = [] unless @groups.key?(group)
        @groups[group] += inputs
    end
end

merge_groups({
               "COMM": %w(TB PROD),
               "BND": %w(KEYS AG GTR BASS),
               "DRM": %w(KICK SNR TOM OH SPDX),
               "VOX": %w(WL BGV CHOIR),
               "SPK": %w(MC LAV),
               "AR": %w(CROWD),
               "TRAX": %w(ABLETON)
             })

# pp @groups
rename_audio_files
