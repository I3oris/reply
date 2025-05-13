module Reply
  private class AlternateScreen
    @char_reader = CharReader.new
    @lines = [] of String
    @offset = 0

    def initialize(text : String)
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

    def self.open(text)
      new(text).open
    end

    def open
      print Term::Cursor.alternate_screen

      refresh_screen

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
    end

    def refresh_screen
      print Term::Cursor.clear_screen
      print Term::Cursor.clear_line

      (self.height - 1).times do |i|
        puts @lines[i + @offset]? || ""
      end
      print ':'
    end

    def down
      if self.height - 1 + @offset < @lines.size
        print Term::Cursor.clear_line
        puts @lines[self.height - 1 + @offset]
        print ':'
        @offset += 1
      end
    end

    def up
      if @offset > 0
        @offset -= 1
        refresh_screen
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
