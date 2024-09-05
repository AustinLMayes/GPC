# Onyx macro functions and cue list definitions

require 'onyx'

module Macros
    extend self

    module CueListIDs
        # Haze machine
        HAZER = 2385

        # House brightness
        HOUSE_PRE = 1330
        HOUSE_BO = 1331
        HOUSE_OPENER = 1332
        HOUSE_PRELIM = 1334
        HOUSE_2_1 = 1335
        HOUSE_2_2 = 1333
        HOUSE_2_3 = 1336
        HOUSE_PREACH = 1337
        HOUSE_ALTAR_HYPE = 1338
        HOUSE_ALTAR_WORSHIP = 1339
        HOUSE_VIDEO = 1718

        # Companion controls
        COMPANION = 3155

        # Stage color cue lists
        IN_OUT = 2168
        PRELIM = 2169
        MESSAGE = 2170
        PRELIM_VIDEO = 2335
        PRELIM_PG = 3377

        # Stage brightness
        STAGE_WORSHIP_SLOW = 2592
        STAGE_WORSHIP_MED = 2591
        STAGE_WORSHIP_FAST = 2588
        STAGE_CENTER_SLOW = 2589
        STAGE_CENTER_MED = 2593
        STAGE_CENTER_FAST = 2594
        STAGE_BO_SLOW = 2595
        STAGE_BO_MED = 2596
        STAGE_BO_FAST = 2597
        STAGE_MESSAGE = 2590

        # Global default look
        DIMMERS_70 = 2172
    end

    # Select (and optionally trigger) a cuelist by name or ID
    def select(ident, cue: 1, trigger: false)
        if ident.to_i.to_s == ident
            ident = ident.to_i
        end
        if ident.is_a?(Integer)
            if trigger
                "SELECTMAIN IntList #{ident}\nTRIGGER IntList #{ident}Q#{cue}"
            else
                "SELECTMAIN IntList #{ident}"
            end
        else
            case ident.downcase
            when "none"
                "SELECTMAIN IntList -2"
            else
                cue_list_id = Onyx::Cuelist.find_one($client, cue_list_name: ident).cue_list_id
                if trigger
                    "SELECTMAIN IntList #{cue_list_id}\nTRIGGER IntList #{cue_list_id}Q#{cue}"
                else
                    "SELECTMAIN IntList #{cue_list_id}"
                end
            end
        end
    end

    # Trigger a cuelist by name or ID
    def trigger(ident, cue: 1)
        if ident.to_i.to_s == ident
            ident = ident.to_i
        end
        if ident.is_a?(Integer)
            "TRIGGER IntList #{ident}Q#{cue}"
        else
            cue_list = Onyx::Cuelist.find_one($client, cue_list_name: ident)
            raise "Cuelist #{ident} not found" if cue_list.nil?
            "TRIGGER IntList #{cue_list.cue_list_id}Q#{cue}"
        end
    end

    # Companion button by index
    def companion(cue)
        "TRIGGER IntList 3155Q#{cue}"
    end

    # Release a cuelist by name or ID
    def release(ident)
        if ident.to_i.to_s == ident
            ident = ident.to_i
        end
        if ident.is_a?(Integer)
            "RELEASE IntList #{ident}"
        else
            case ident.downcase
            when "this"
                "REL THIS CUELIST"
            else
                if ident.include?(":")
                    start, stop = ident.split(":").map(&:strip)
                    "REL CUELISTS #{start} TO #{stop} Time Default"
                else
                    cl = Onyx::Cuelist.find_one($client, cue_list_name: ident)
                    raise "Cuelist #{ident} not found" if cl.nil?
                    "RELEASE IntList #{cl.cue_list_id}"
                end
            end
        end
    end

    # Reset timecode
    def reset_timecode
        "TIMECODE Reset"
    end

    # Parse the ruby object from a service.json file
    def from_json(json)
        case json[:type].downcase
        when "house" # House look
            raise "Missing house look" if json[:look].nil?
            case json[:look].downcase
            when "pre"
                "TRIGGER IntList #{CueListIDs::HOUSE_PRE}Q1"
            when "bo"
                "TRIGGER IntList #{CueListIDs::HOUSE_BO}Q1"
            when "opener"
                "TRIGGER IntList #{CueListIDs::HOUSE_OPENER}Q1"
            when "prelim"
                "TRIGGER IntList #{CueListIDs::HOUSE_PRELIM}Q1"
            when "2-1"
                "TRIGGER IntList #{CueListIDs::HOUSE_2_1}Q1"
            when "2-2"
                "TRIGGER IntList #{CueListIDs::HOUSE_2_2}Q1"
            when "2-3"
                "TRIGGER IntList #{CueListIDs::HOUSE_2_3}Q1"
            when "preach"
                "TRIGGER IntList #{CueListIDs::HOUSE_PREACH}Q1"
            when "altar-hype"
                "TRIGGER IntList #{CueListIDs::HOUSE_ALTAR_HYPE}Q1"
            when "altar-worship"
                "TRIGGER IntList #{CueListIDs::HOUSE_ALTAR_WORSHIP}Q1"
            when "video"
                "TRIGGER IntList #{CueListIDs::HOUSE_VIDEO}Q1"
            else
                raise "Unknown house macro: #{json[:look]}"
            end
        when "stage" # Stage brightness look
            raise "Missing stage look" if json[:look].nil?
            case json[:look].downcase
            when "worship-slow"
                "TRIGGER IntList #{CueListIDs::STAGE_WORSHIP_SLOW}Q1"
            when "worship-med"
                "TRIGGER IntList #{CueListIDs::STAGE_WORSHIP_MED}Q1"
            when "worship-fast"
                "TRIGGER IntList #{CueListIDs::STAGE_WORSHIP_FAST}Q1"
            when "center-slow"
                "TRIGGER IntList #{CueListIDs::STAGE_CENTER_SLOW}Q1"
            when "center-med"
                "TRIGGER IntList #{CueListIDs::STAGE_CENTER_MED}Q1"
            when "center-fast"
                "TRIGGER IntList #{CueListIDs::STAGE_CENTER_FAST}Q1"
            when "bo-slow"
                "TRIGGER IntList #{CueListIDs::STAGE_BO_SLOW}Q1"
            when "bo-med"
                "TRIGGER IntList #{CueListIDs::STAGE_BO_MED}Q1"
            when "bo-fast"
                "TRIGGER IntList #{CueListIDs::STAGE_BO_FAST}Q1"
            when "message"
                "TRIGGER IntList #{CueListIDs::STAGE_MESSAGE}Q1"
            else
                raise "Unknown stage macro: #{json[:look]}"
            end
        when "select" # Select a cuelist
            raise "Missing select macro" if json[:id].nil?
            cuelist = json[:id].to_i.to_s == json[:id] ? json[:id].to_i : json[:id].to_s
            cue = json[:cue].nil? ? 1 : json[:cue].to_i
            select(cuelist, cue: cue, trigger: json[:trigger] || false)
        when "trigger" # Trigger a cuelist
            raise "Missing trigger macro" if json[:id].nil?
            cuelist = json[:id].to_i.to_s == json[:id] ? json[:id].to_i : json[:id].to_s
            cue = json[:cue].nil? ? 1 : json[:cue].to_i
            trigger(cuelist, cue: cue)
        when "release" # Release a cuelist
            raise "Missing release macro" if json[:id].nil?
            cuelist = json[:id].to_i.to_s == json[:id] ? json[:id].to_i : json[:id].to_s
            release(cuelist)
        when "haze" # Set haze level
            raise "Missing haze macro" if json[:output].nil?
            id = case json[:output].downcase
                when "off"
                    1
                when "light"
                    2
                 when "med"
                    3
                 when "max"
                    4
                else
                    raise "Unknown haze macro: #{json[:type]}"
                 end
            "TRIGGER IntList #{CueListIDs::HAZER}Q#{id}"
        when "reset" # Reset timecode
            reset_timecode
        else
            raise "Unknown macro: #{args[0]}"
        end
    end
end
