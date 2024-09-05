# Wrapper around the Planning Center API which adds helpful extra functionality

require "pco_api"
require "common"
require_relative "section"
require 'active_support/time'

module PCO
    extend self

    @pco_api = PCO::API.new(basic_auth_token: ENV["PCO_API_KEY"], basic_auth_secret: ENV["PCO_API_SECRET"])

    # Get the service type by name
    def find_service_type_by_name(name)
        @pco_api.services.v2.service_types.get["data"].each do |service_type|
            if service_type["attributes"]["name"] == name
                return service_type
            end
        end
        raise "Service type not found: #{name}"
    end

    # Find the latest plan for a service type
    def get_plan(service_type_id, page = 1, last = nil, res = [])
        puts "Getting plan page #{page}..."
        today = Date.today
        plans = @pco_api.services.v2.service_types[service_type_id].plans.get(order: "-sort_date", per_page: 50, offset: (page - 1) * 50)["data"]
        plans.each do |plan|
            time_raw = plan["attributes"]["sort_date"]
            time = Time.parse(time_raw).to_i
            if time < (today).to_time.to_i
                return res
            end
            res.unshift(plan)
            last = plan
        end
        get_plan(service_type_id, page + 1, last, res)
    end

    # Get the title and author of a song
    def get_song_info(id, arrangement_id)
        song = @pco_api.services.v2.songs[id].get["data"]
        arrangement = @pco_api.services.v2.songs[song["id"]].arrangements[arrangement_id].get["data"]
        arrangement_name = arrangement["attributes"]["name"]
        arrangement_name = arrangement_name.split(" - ").first
        author = arrangement_name.gsub("Arrangement", "").strip
        if author == "Default" && !song["attributes"]["author"].nil?
            author = song["attributes"]["author"].split(",").first.gsub(/[bB]y/, "").strip
        end
        author = special_case_author(song["attributes"]["title"]) || author
        title_raw = song["attributes"]["title"].strip
        title = special_case_name(title_raw) || title_raw
        {
            title: title.gsub("'", ""),
            author: author
        }
    end

    # Execute methods on items in a plan
    def act_on_items(plan, song, header, generic)
        info "Getting items for plan #{plan['attributes']['sort_date']}..."
        items = @pco_api.services.v2.service_types[plan["relationships"]["service_type"]["data"]["id"]].plans[plan["id"]].items.get(per_page: 50)["data"]
        items.each do |item|
            position = item["attributes"]["service_position"]
            next unless position == "during"
            type = item["attributes"]["item_type"]
            case type
            when "song"
                song.(item)
            when "header"
                header.(item)
            when "item"
                generic.(item)
            else
                raise "Unknown item type: #{type}"
            end
        end
    end

    private

    def special_case_author(name)
        return case name.downcase
        when "gratitude"
            "Brandon Lake"
        when "give me jesus (wilson)"
            "James Wilson"
        when "see a victory"
            "Elevation Worship"
        else
            nil
        end
    end

    def special_case_name(name)
        return case name.downcase
        when "give me jesus (wilson)"
            "Give Me Jesus"
        else
            nil
        end
    end
end
