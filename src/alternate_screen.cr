module Reply
  private class AlternateScreen
    property? color

    @char_reader = CharReader.new
    @lines = [] of String
    @offset = 0

    def initialize(text : String, @color = true)
      text.each_line do |line|
        @lines += ExpressionEditor.parts_from_colorized(line, width: self.width)
      end
    end

    setter height : Int32? = nil
    setter width : Int32? = nil

    def width
      @width || Term::Size.width
    end

    def height
      @height || Term::Size.height
    end

    def self.open(text, color? = true)
      new(text, color?).open
    end

    def open
      print Term::Cursor.save
      print Term::Cursor.alternate_screen

      print Term::Cursor.clear_screen
      print Term::Cursor.clear_line

      (self.height - 1).times do |i|
        puts @lines[i + @offset]? || ""
      end

      print end_character

      loop do
        case input = @char_reader.read_char
        when 'q', CharReader::Sequence::ESCAPE, CharReader::Sequence::CTRL_D, CharReader::Sequence::CTRL_C, CharReader::Sequence::ALT_D # ?
          break
        when ' ', CharReader::Sequence::ENTER, CharReader::Sequence::DOWN
          down
        when CharReader::Sequence::UP
          up
        when String
          on_repeated_sequence("\e[A", input) { up }
          on_repeated_sequence("\e[B", input) { down }
        end
      end
    ensure
      print Term::Cursor.normal_screen
      print Term::Cursor.restore
    end

    private def down
      if self.height + @offset <= @lines.size
        print Term::Cursor.clear_line
        puts @lines[self.height - 1 + @offset]

        @offset += 1
        print end_character
      end
    end

    private def up
      if @offset > 0
        print Term::Cursor.move_to 0, 0
        print Term::Cursor.scroll_up

        puts @lines[@offset - 1]
        print Term::Cursor.down self.height - 2
        print Term::Cursor.clear_line

        @offset -= 1
        print end_character
      end
    end

    private def end_character
      if self.height + @offset >= @lines.size + 1
        "(END)".colorize.toggle(color?).cyan.bold.on_white
      else
        ':'
      end
    end

    private def on_repeated_sequence(sequence, input, &)
      if input.starts_with? sequence
        until input.nil? || input.empty?
          input = input.lchop?(sequence)
          yield
        end
      end
    end
  end
end
