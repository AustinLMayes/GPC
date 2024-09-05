# Generate a Bitfocus Companion page JSON module using templates for a definitions file

class CompanionPage

    attr_reader :controls, :button_definitions, :button_index

    def initialize
        @controls = {}
        @button_definitions = JSON.parse(File.read("/Users/austinmayes/Projects/Ruby/GPC/button_defs.json"))
        add_button("home", "HOME", index: 1)
        add_button("r-thru", "R-THRU", index: 3)
        add_button("sd-lock", "SD LOCK", index: 4)
        @button_index = 9
    end

    def to_json
        {
            version: 3,
            type: "page",
            controls: @controls,
            page: {
                name: "MASTER CONTROL",
            },
            # Ugh - since we use this device directly, companion for some reason needs to know about it in the page even though it's defined in the global config
            # The import will just fail with a random error if this isn't here
            "instances": {
                "o9c4iq_xaVccR5XrnclO8": {
                  "instance_type": "renewedvision-propresenter",
                  "label": "A-CG-2",
                  "isFirstInit": false,
                  "config": {
                    "product": "ProPresenter",
                    "host": "192.168.7.81",
                    "port": "50546",
                    "pass": "church",
                    "indexOfClockToWatch": "0",
                    "GUIDOfStageDisplayScreenToWatch": "0",
                    "sendPresentationCurrentMsgs": "no",
                    "use_sd": "no",
                    "sdport": "",
                    "sdpass": "",
                    "clientVersion": "701",
                    "control_follower": "no",
                    "followerhost": "",
                    "followerport": "20652",
                    "followerpass": "",
                    "import_to": "new"
                  },
                  "enabled": true,
                  "lastUpgradeIndex": -1
                }
              },
            oldPageNumber: 40
        }.to_json
    end

    def add_button(ref_id, button_name, index: @button_index += 1, item: nil)
        ref = @button_definitions[ref_id]
        raise "Button definition not found: #{ref_id}" if ref.nil?
        ref = Marshal.load(Marshal.dump(ref))
        ref["style"]["text"] = button_name
        unless item.nil?
            ref["steps"]['0']['action_sets']['down'].each do |action|
                next unless action["action"] == "button_pressrelease"
                next unless action['options']['page'] == 15
                action['options']['bank'] = item + 1
                info "Setting item to #{item}"
            end
        end
        @controls["bank:40-#{index}"] = ref
    end
end
