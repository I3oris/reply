require "spec"
require "../src/reply"

module Reply
  class AutoCompletion
    def verify(open, entries = [] of String, name_filter = "", cleared = false, selection_pos = nil)
      self.open?.should eq open
      self.cleared?.should eq cleared
      self.name_filter.should eq name_filter
      self.entries.should eq entries
      @selection_position.should eq selection_pos
    end

    def verify_display(max_height, min_height, with_width, display, height)
      height_got = nil

      display_got = String.build do |io|
        height_got = self.display_entries(io, color: false, width: with_width, max_height: max_height, min_height: min_height)
      end
      display_got.should eq display
      height_got.should eq height
      (display_got.split("\n").size - 1).should eq height
    end

    def verify_display(max_height, with_width, display, height)
      verify_display(max_height, 0, with_width, display, height)
    end
  end

  class ExpressionEditor
    def verify(expression : String)
      self.expression.should eq expression
    end

    def verify(x : Int32, y : Int32, scroll_offset = 0)
      {self.x, self.y}.should eq({x, y})
      @scroll_offset.should eq scroll_offset
    end

    def verify(expression : String, x : Int32, y : Int32, scroll_offset = 0)
      self.verify(expression)
      self.verify(x, y, scroll_offset)
    end

    def verify_output(output)
      self.output.to_s.should eq output
    end
  end

  class History
    def verify(entries, index)
      @history.should eq Deque(Array(String)).new(entries)
      @index.should eq index
    end
  end

  class Search
    setter failed

    def verify(query, open = true, failed = false)
      @query.should eq query
      @open.should eq open
      @failed.should eq failed
    end

    def verify_footer(footer, height)
      String.build do |io|
        footer(io, true).should eq height
      end.should eq footer
    end
  end

  struct CharReader
    def verify_read(to_read, expect : CharReader::Sequence)
      verify_read(to_read, [expect])
    end

    def verify_read(to_read, expect : Array)
      chars = [] of Char | CharReader::Sequence | String?
      io = IO::Memory.new
      io << to_read
      io.rewind
      loop do
        c = self.read_char(io)
        break if c == CharReader::Sequence::EOF
        chars << c
      end
      chars.should eq expect
    end
  end

  class SpecReader < Reader
    def auto_complete(current_word : String, expression_before : String)
      return "title", %w(hello world hey)
    end

    getter auto_completion
  end

  class SpecReaderWithSearch < Reader
    def disable_search?
      false
    end

    getter search
  end

  class SpecReaderWithEqual < Reader
    def initialize
      super
      self.word_delimiters = {{" \n\t+-*/,;@&%<>^\\[](){}|.~".chars}}
    end

    def auto_complete(current_word : String, expression_before : String)
      return "title", %w(hello world= hey)
    end

    getter auto_completion
  end

  class SpecReaderWithAutoCompletionRetrigger < Reader
    def initialize
      super
      self.word_delimiters.delete(':')
    end

    def auto_complete(current_word : String, expression_before : String)
      if current_word.ends_with? "::"
        return "title", ["#{current_word}foo", "#{current_word}foobar", "#{current_word}bar"]
      else
        return "title", %w(foo foobar bar)
      end
    end

    def auto_completion_retrigger_when(current_word : String) : Bool
      current_word.ends_with? ':'
    end

    getter auto_completion
  end

  class SpecCommandReader < Reader
    include Commands

    def do_method
      output.puts "executing method"
    end

    @[Help("Help summary")]
    def do_method_with_single_arg(arg)
      output.puts "executing method_with_single_arg, args: #{arg}"
    end

    @[Help("Help summary", details: "Help details")]
    def do_method_with_complex_args(arg1, arg2 : String, arg3 : String?, arg4 = "foo", arg5 = nil, *args)
      all_args = [arg1, arg2, arg3, arg4, arg5] + args[0]
      output.puts "executing method_with_complex_args, args: #{all_args.join(" ") { |arg| arg || "nil" }}"
    end

    @[Exit]
    def do_exit_method
      output.puts "executing exit_method"
    end

    def exit_result?(result)
      result.is_a? ExitResult
    end
  end

  module SpecHelper
    def self.auto_completion(returning results)
      results = results.clone
      AutoCompletion.new do
        results
      end
    end

    def self.expression_editor
      editor = ExpressionEditor.new do |line_number, _color|
        # Prompt size = 5
        "p:#{sprintf("%02d", line_number)}>"
      end
      editor.output = IO::Memory.new
      editor.color = false
      editor.height = 5
      editor.width = 15
      editor
    end

    def self.history(with entries = [] of Array(String))
      history = History.new
      entries.each { |e| history << e }
      history
    end

    def self.search
      Search.new.tap &.open
    end

    def self.char_reader(buffer_size = 64)
      CharReader.new(buffer_size)
    end

    def self.reader(type = SpecReader)
      reader = type.new
      reader.output = IO::Memory.new
      reader.color = false
      reader.editor.height = 15
      reader.editor.width = 30
      reader
    end

    def self.send(io, value)
      io << value
      Fiber.yield
    end
  end
end
