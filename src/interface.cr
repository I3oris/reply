require "./history"
require "./expression_editor"
require "./char_reader"
require "./auto_completion_interface"
require "colorize"

module Reply
  class Interface
    @editor : ExpressionEditor
    @auto_completion : AutoCompletionInterface
    @history = History.new
    @char_reader = CharReader.new
    getter line_number = 1

    delegate :color?, :color=, :lines, :output, :output=, to: @editor

    def initialize
      @editor = ExpressionEditor.new do |expr_line_number, color?|
        String.build do |io|
          prompt(io, @line_number + expr_line_number, color?)
        end
      end

      @auto_completion = AutoCompletionInterface.new do |name_filter, expression|
        auto_complete(name_filter, expression)
      end

      @editor.set_header do |io, previous_height|
        @auto_completion.display_entries(io, color?, max_height: {10, Term::Size.height - 1}.min, min_height: previous_height)
      end

      @editor.set_highlight do |expression|
        highlight(expression)
      end
    end

    def prompt(io : IO, line_number : Int32, color? : Bool)
      io << "$:"
      io << sprintf("%03d", line_number)
      io << "> "
    end

    def auto_complete(current_word : String, expression_before : String)
      return [] of String, ""
    end

    # `"`, `'`, are not considered as delimiter
    def word_delimiters
      /[ \n\t\+\-\*\/,;@&%<>\^\\\[\]\(\)\{\}\|\.\~:=\!\?]/
    end

    def continue?(expression : String)
      false
    end

    def indentation_level(expression_before_cursor : String)
      0
    end

    def reindent_line(line : String)
      nil
    end

    def format(expression : String)
      nil
    end

    def highlight(expression : String)
      expression
    end

    def save_in_history?(expression : String)
      true
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def read_next : String?
      @editor.prompt_next

      loop do
        read = @char_reader.read_char(from: STDIN)
        case read
        when :enter
          @auto_completion.close
          on_enter { |line| return line }
        when :up
          has_moved = @editor.move_cursor_up

          if !has_moved
            @history.up(@editor.lines) do |expression|
              @editor.replace(expression)
              @editor.move_cursor_to_end
            end
          end
        when :down
          has_moved = @editor.move_cursor_down

          if !has_moved
            @history.down(@editor.lines) do |expression|
              @editor.replace(expression)
              @editor.move_cursor_to_end_of_line(y: 0)
            end
          end
        when :left
          @editor.move_cursor_left
        when :right
          @editor.move_cursor_right
        when :ctrl_up
          on_ctrl_up { |line| return line }
        when :ctrl_down
          on_ctrl_down { |line| return line }
        when :ctrl_left
          on_ctrl_left { |line| return line }
        when :ctrl_right
          on_ctrl_right { |line| return line }
        when :delete
          @editor.update { delete }
        when :back
          auto_complete_remove_char if @auto_completion.open?
          @editor.update { back }
        when :tab
          on_tab
        when :shift_tab
          on_tab(shift_tab: true)
        when :escape
          @auto_completion.close
          @editor.update
        when :insert_new_line
          @auto_completion.close
          @editor.update { insert_new_line(indent: self.indentation_level(@editor.expression_before_cursor)) }
        when :move_cursor_to_begin
          @editor.move_cursor_to_begin
        when :move_cursor_to_end
          @editor.move_cursor_to_end
        when :keyboard_interrupt
          @auto_completion.close
          @editor.end_editing
          output.puts "^C"
          @history.set_to_last
          @editor.prompt_next
          next
        when Char
          on_char(read)
        when String
          @editor.update do
            @editor << read
          end
        when :exit
          output.puts
          return nil
        end

        if !read.in?(:tab, :enter, :insert_new_line, :shift_tab, :escape, :back) && @auto_completion.open?
          auto_complete_insert_char(read)
          @editor.update
        end
      end
    end

    def run(& : String -> _)
      loop do
        yield read_next || break
      end
    end

    def reset
      @line_number = 1
      @auto_completion.close
    end

    def clear_history
      @history.clear
    end

    # If overridden, can yield an expression to giveback to `run`, see `PryInterface`.
    private def on_ctrl_up(& : String ->)
      @editor.scroll_down
    end

    private def on_ctrl_down(& : String ->)
      @editor.scroll_up
    end

    private def on_ctrl_left(& : String ->)
      # TODO: move one word backward
      @editor.move_cursor_left
    end

    private def on_ctrl_right(& : String ->)
      # TODO: move one word forward
      @editor.move_cursor_right
    end

    private def on_enter(&)
      if @editor.cursor_on_last_line? && continue?(@editor.expression)
        @editor.update { insert_new_line(indent: self.indentation_level(@editor.expression_before_cursor)) }
      else
        submit_expr
        yield @editor.expression
      end
    end

    private def on_tab(shift_tab = false)
      line = @editor.current_line

      # Retrieve the word under the cursor (corresponding to the method name being write)
      word_begin, word_end = self.word_on_cursor_begin_end
      word_on_cursor = line[word_begin..word_end]

      if @auto_completion.open?
        if shift_tab
          replacement = @auto_completion.selection_previous
        else
          replacement = @auto_completion.selection_next
        end
      else
        # # Set auto-completion context from repl, allow auto-completion to take account of previously defined types, methods and local vars.
        # @crystal_completer.set_context(repl) if repl

        # Get hole expression before cursor, allow auto-completion to deduce the receiver type
        expr = @editor.expression_before_cursor(x: word_begin)

        # Compute auto-completion, return `replacement` (`nil` if no entry, full name if only one entry, or the begin match of entries otherwise)
        replacement = @auto_completion.complete_on(word_on_cursor, expr)

        if replacement && @auto_completion.entries.size >= 2
          @auto_completion.open
        end
      end

      if replacement
        @editor.update do
          # Replace `word_on_cursor` by the replacement word:
          @editor.current_line = line.sub(word_begin..word_end, replacement) # if replacement
        end

        # Move cursor:
        @editor.move_cursor_to(x: word_begin + replacement.size, y: @editor.y)
      end
    end

    private def on_char(char)
      @editor.update do
        @editor << char
        line = @editor.current_line.rstrip(' ')

        if @editor.x == line.size
          if shift = self.reindent_line(line)
            indent = self.indentation_level(@editor.expression_before_cursor)
            new_indent = (indent + shift).clamp 0..
            @editor.current_line = "  "*new_indent + @editor.current_line.lstrip(' ')
          end
        end
      end
    end

    private def auto_complete_insert_char(read)
      if read.is_a? Char && word_char?(@editor.x - 1)
        # line = @editor.current_line

        # Retrieve the word under the cursor (corresponding to the method name being write)
        # word_begin, word_end = @editor.word_bound
        # word_on_cursor = line[word_begin..word_end]

        @auto_completion.name_filter = self.word_on_cursor
      elsif @editor.expression_scrolled? || read.is_a?(String)
        @auto_completion.close
      else
        @auto_completion.clear
      end
    end

    private def auto_complete_remove_char
      if word_char?(@editor.x - 1)
        # line = @editor.current_line

        # word_begin, word_end = @editor.word_bound
        # word_on_cursor =
        @auto_completion.name_filter = self.word_on_cursor[...-1]
      else
        @auto_completion.clear
      end
    end

    # Returns begin and end of the word under the cursor:
    private def word_on_cursor_begin_end
      x = @editor.x
      line = @editor.current_line
      word_begin = line.rindex(self.word_delimiters, offset: {x - 1, 0}.max) || -1
      word_end = line.index(self.word_delimiters, offset: x) || line.size

      {word_begin + 1, word_end - 1}
    end

    private def word_on_cursor
      word_begin, word_end = word_on_cursor_begin_end()

      @editor.current_line[word_begin..word_end]
    end

    # Returns true is the char at *x*, *y* is a word char.
    private def word_char?(x)
      if x >= 0 && (ch = @editor.current_line[x]?)
        !(self.word_delimiters =~ ch.to_s)
      end
    end

    private def submit_expr(*, history = true)
      formated = format(@editor.expression).try &.split('\n')
      @editor.end_editing(replacement: formated)

      @line_number += @editor.lines.size
      @history << @editor.lines if history && save_in_history?(@editor.expression)
    end
  end
end
