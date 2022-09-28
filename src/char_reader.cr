module Reply
  private struct CharReader
    enum Sequence
      EOF
      UP
      DOWN
      RIGHT
      LEFT
      ENTER
      ALT_ENTER
      ESCAPE
      DELETE
      BACK
      CTRL_C
      CTRL_D
      CTRL_E
      CTRL_A
      CTRL_X
      CTRL_UP
      CTRL_DOWN
      CTRL_LEFT
      CTRL_RIGHT
      TAB
      SHIFT_TAB
      HOME
      END
    end

    def initialize(buffer_size = 8192)
      @slice_buffer = Bytes.new(buffer_size)
    end

    def read_char(from io = STDIN)
      nb_read = raw(io, &.read(@slice_buffer))

      parse_escape_sequence(@slice_buffer[0...nb_read])
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_escape_sequence(chars : Bytes) : Char | Sequence | String?
      return String.new(chars) if chars.size > 6
      return Sequence::EOF if chars.empty?

      case chars[0]?
      when '\e'.ord
        case chars[1]?
        when '['.ord
          case chars[2]?
          when 'A'.ord then Sequence::UP
          when 'B'.ord then Sequence::DOWN
          when 'C'.ord then Sequence::RIGHT
          when 'D'.ord then Sequence::LEFT
          when 'Z'.ord then Sequence::SHIFT_TAB
          when '3'.ord
            if chars[3]? == '~'.ord
              Sequence::DELETE
            end
          when '1'.ord
            if {chars[3]?, chars[4]?} == {';'.ord, '5'.ord}
              case chars[5]?
              when 'A'.ord then Sequence::CTRL_UP
              when 'B'.ord then Sequence::CTRL_DOWN
              when 'C'.ord then Sequence::CTRL_RIGHT
              when 'D'.ord then Sequence::CTRL_LEFT
              end
            elsif chars[3]? == '~'.ord # linux console HOME
              Sequence::HOME
            end
          when '4'.ord # linux console END
            if chars[3]? == '~'.ord
              Sequence::END
            end
          when 'H'.ord # xterm HOME
            Sequence::HOME
          when 'F'.ord # xterm END
            Sequence::END
          end
        when '\t'.ord
          Sequence::SHIFT_TAB
        when '\r'.ord
          Sequence::ALT_ENTER
        when 'O'.ord
          if chars[2]? == 'H'.ord # gnome terminal HOME
            Sequence::HOME
          elsif chars[2]? == 'F'.ord # gnome terminal END
            Sequence::END
          end
        else
          Sequence::ESCAPE
        end
      when '\r'.ord, '\n'.ord
        Sequence::ENTER
      when '\t'.ord
        Sequence::TAB
      when ctrl('c')
        Sequence::CTRL_C
      when ctrl('d')
        Sequence::CTRL_D
      when ctrl('x')
        Sequence::CTRL_X
      when ctrl('a')
        Sequence::CTRL_A
      when ctrl('e')
        Sequence::CTRL_E
      when '\0'.ord
        Sequence::EOF
      when 0x7f
        Sequence::BACK
      else
        if chars.size == 1
          chars[0].chr
        end
      end || String.new(chars)
    end

    private def raw(io : T, &) forall T
      {% if T.has_method?(:raw) %}
        if io.tty?
          io.raw { yield io }
        else
          yield io
        end
      {% else %}
        yield io
      {% end %}
    end

    private def ctrl(k)
      (k.ord & 0x1f)
    end
  end
end
