require "spec"
require "../src/reply"

module Reply
  module Term::Size
    # For spec, simulate of term size of 5 lines, and 15 characters wide:
    class_property size = {15, 5}
  end

  class Reply::AutoCompletionInterface
    @width : Int32 = Term::Size.width

    # Simulate term width for auto-completion handler.
    def term_width
      @width
    end

    # Change temporally the simulated term size for auto-completion handler.
    def with_term_width(w)
      old_size = @width
      @width = w
      yield
      @width = old_size
    end

    def verify_display(max_height, clear_size, display, height)
      height_got = nil

      display_got = String.build do |io|
        height_got = self.display_entries(io, false, max_height, clear_size)
      end
      display_got.should eq display
      height_got.should eq height
      (display_got.split("\n").size - 1).should eq height
    end

    def verify_display(max_height, display, height)
      verify_display(max_height, 0, display, height)
    end
  end

  class ExpressionEditor
    def verify(expression : String)
      self.expression.should eq expression
    end

    def verify(x : Int32, y : Int32)
      {self.x, self.y}.should eq({x, y})
    end

    def verify(expression : String, x : Int32, y : Int32)
      self.verify(expression)
      self.verify(x, y)
    end

    def verify_output(output)
      self.output.to_s.should eq output
    end
  end

  class History
    def verify(entries, index)
      @history.should eq entries
      @index.should eq index
    end
  end

  struct CharReader
    def verify_read(to_read, expect : Array)
      chars = [] of Char | Symbol | String?
      io = IO::Memory.new
      io << to_read
      io.rewind
      loop do
        c = self.read_char(io)
        chars << c
        break if c == :exit
      end
      chars.should eq expect
    end
  end

  module SpecHelper
    def self.auto_completion_interface(returning results)
      results = results.clone
      AutoCompletionInterface.new do
        results
      end
    end

    def self.expression_editor
      editor = ExpressionEditor.new do |line_number, _color?|
        # Prompt size = 5
        "p:#{sprintf("%02d", line_number)}>"
      end
      editor.output = IO::Memory.new
      editor.color = false
      editor
    end

    def self.history(with entries = [] of Array(String))
      history = History.new
      entries.each { |e| history << e }
      history
    end

    def self.char_reader(buffer_size = 64)
      CharReader.new(buffer_size)
    end
  end
end
