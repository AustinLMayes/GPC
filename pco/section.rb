# Planning Center Section mapping

class Section
    PRE = 0
    OPENER = 1
    PRELIM = 2
    WORSHIP = 3
    MESSAGE = 4
    ALTAR = 5
    POST = 6
    PRAYER = 7

    def self.allow_song?(section)
        section == OPENER || section == WORSHIP || section == ALTAR
    end

    def self.name(section)
        case section
        when PRE
            "Pre-Experience"
        when OPENER
            "Opener"
        when PRELIM
            "Prelim"
        when WORSHIP
            "Worship"
        when MESSAGE
            "Message"
        when ALTAR
            "Altar"
        when POST
            "Post-Experience"
        when PRAYER
            "Prayer"
        else
            raise "Unknown section #{section}"
        end
    end

    def self.companion_id(section, index)
        case section
        when PRE
            "pre-x"
        when OPENER
            index == 0 ? "open-first" : "open-other"
        when PRELIM
            "prelim"
        when WORSHIP
            index == 0 ? "worship-first" : "worship-other"
        when MESSAGE
            "message"
        when ALTAR
            "altar"
        when POST
            "post-x"
        when PRAYER
            "prayer"
        else
            raise "Unknown section #{section}"
        end
    end

    def self.from_heading(heading, index)
        heading = heading.downcase
        if heading.include?("experience") || heading.include?("pre-show")
            PRE
        elsif heading.include?("prelim")
            PRELIM
        elsif heading.include?("open")
            OPENER
        elsif heading.include?("worship")
            WORSHIP
        elsif heading.include?("message") || heading.include?("sermon")
            MESSAGE
        elsif heading.include?("altar")
            ALTAR
        elsif heading.include?("post")
            POST
        elsif heading.include?("prayer")
            PRAYER
        else
            warn "Unknown section heading: #{heading} - Falling back to next section based on index"
            case index
            when 0
                OPENER
            when 1
                PRELIM
            when 2
                WORSHIP
            when 3
                MESSAGE
            when 4
                ALTAR
            when 5
                POST
            when 6
                PRAYER
            when 7
                WORSHIP # Fallback to worship after prayer
            else
                raise "Unknown section index #{index}"
            end
        end
    end
end
