require "./history"
require "./expression_editor"
require "./char_reader"
require "./auto_completion"

module Reply
  # Reader for your REPL.
  #
  # Create a subclass of it and override methods to customize behavior.
  #
  # ```
  # class MyReader < Reply::Reader
  #   def prompt(io, line_number, color?)
  #     io << "reply> "
  #   end
  # end
  # ```
  #
  # Run the REPL with `run`:
  #
  # ```
  # reader = MyReader.new
  #
  # reader.run do |expression|
  #   # Eval expression here
  #   puts " => #{expression}"
  # end
  # ```
  #
  # Or with `read_next`:
  # ```
  # loop do
  #   expression = reader.read_next
  #   break unless expression
  #
  #   # Eval expression here
  #   puts " => #{expression}"
  # end
  # ```
  class Reader
    # General architecture:
    #
    # ```
    # SDTIN -> CharReader -> Reader -> ExpressionEditor -> STDOUT
    #                        ^    ^
    #                        |    |
    #                   History  AutoCompletion
    # ```

    getter history = History.new
    getter editor : ExpressionEditor
    @auto_completion : AutoCompletion
    @char_reader = CharReader.new
    getter line_number = 1

    delegate :color?, :color=, :lines, :output, :output=, to: @editor

    def initialize
      @editor = ExpressionEditor.new do |expr_line_number, color?|
        String.build do |io|
          prompt(io, @line_number + expr_line_number, color?)
        end
      end

      @auto_completion = AutoCompletion.new(&->auto_complete(String, String))
      @auto_completion.set_display_title(&->auto_completion_display_title(IO, String))
      @auto_completion.set_display_entry(&->auto_completion_display_entry(IO, String, String))
      @auto_completion.set_display_selected_entry(&->auto_completion_display_selected_entry(IO, String))

      @editor.set_header do |io, previous_height|
        @auto_completion.display_entries(io, color?, max_height: {10, Term::Size.height - 1}.min, min_height: previous_height)
      end

      @editor.set_highlight(&->highlight(String))
    end

    # Override to customize the prompt.
    #
    # Toggle the colorization following *color?*.
    #
    # default: `$:001> `
    def prompt(io : IO, line_number : Int32, color? : Bool)
      io << "$:"
      io << sprintf("%03d", line_number)
      io << "> "
    end

    # Override to enable expression highlighting.
    #
    # default: uncolored `expression`
    def highlight(expression : String)
      expression
    end

    # Override this method to makes the interface continue on multiline, depending of the expression.
    #
    # default: `false`
    def continue?(expression : String)
      false
    end

    # Override to enable reformatting after submitting.
    #
    # default: unchanged `expression`
    def format(expression : String)
      nil
    end

    # Override to return the expected indentation level in function of expression before cursor.
    #
    # default: `0`
    def indentation_level(expression_before_cursor : String)
      0
    end

    # Override this method to return the regex delimiting words.
    #
    # default: `/[ \n\t\+\-\*\/,;@&%<>"'\^\\\[\]\(\)\{\}\|\.\~:=\!\?]/`
    def word_delimiters
      /[ \n\t\+\-\*\/,;@&%<>"'\^\\\[\]\(\)\{\}\|\.\~:=\!\?]/
    end

    # Override to select with expression is saved in history.
    #
    # default: `!expression.blank?`
    def save_in_history?(expression : String)
      !expression.blank?
    end

    # Override to integrate auto-completion.
    #
    # *current_word* is picked following `word_delimiters`.
    # It expects to return `Tuple` with:
    # * a title : `String`
    # * the auto-completion results : `Array(String)`
    #
    # default: `{"", [] of String}`
    def auto_complete(current_word : String, expression_before : String)
      return "", [] of String
    end

    # Override to customize how title is displayed.
    #
    # default: `title` underline + `":"`
    def auto_completion_display_title(io : IO, title : String)
      @auto_completion.default_display_title(io, title)
    end

    # Override to customize how entry is displayed.
    #
    # Entry is split in two (`entry_matched` + `entry_remaining`). `entry_matched` correspond
    # to the part already typed when auto-completion was triggered.
    #
    # default: `entry_matched` bright + `entry_remaining` normal.
    def auto_completion_display_entry(io : IO, entry_matched : String, entry_remaining : String)
      @auto_completion.default_display_entry(io, entry_matched, entry_remaining)
    end

    # Override to customize how the selected entry is displayed.
    #
    # default: `entry` bright on dark grey
    def auto_completion_display_selected_entry(io : IO, entry : String)
      @auto_completion.default_display_selected_entry(io, entry)
    end

    # Override to enable line re-indenting.
    #
    # This methods is called each time a character is entered.
    #
    # You should return either:
    # * `nil`: keep the line as it
    # * `Int32` value: re-indent the line by an amount equal to the returned value, relatively to `indentation_level`.
    #   (0 to follow `indentation_level`)
    #
    # See `example/crystal_repl`.
    #
    # default: `nil`
    def reindent_line(line : String)
      nil
    end

    def read_next(from io : IO = STDIN) : String? # ameba:disable Metrics/CyclomaticComplexity
      @editor.prompt_next

      loop do
        read = @char_reader.read_char(from: io)
        case read
        in Char             then on_char(read)
        in String           then on_string(read)
        in .enter?          then on_enter { |line| return line }
        in .up?             then on_up
        in .ctrl_p?         then on_up
        in .down?           then on_down
        in .ctrl_n?         then on_down
        in .left?           then on_left
        in .right?          then on_right
        in .ctrl_up?        then on_ctrl_up { |line| return line }
        in .ctrl_down?      then on_ctrl_down { |line| return line }
        in .ctrl_left?      then on_ctrl_left { |line| return line }
        in .ctrl_right?     then on_ctrl_right { |line| return line }
        in .delete?         then on_delete
        in .back?           then on_back
        in .tab?            then on_tab
        in .shift_tab?      then on_tab(shift_tab: true)
        in .escape?         then on_escape
        in .alt_enter?      then on_enter(alt_enter: true) { }
        in .home?, .ctrl_a? then on_begin
        in .end?, .ctrl_e?  then on_end
        in .ctrl_k?         then delete_after
        in .ctrl_u?         then delete_before
        in .alt_f?          then move_word_forward
        in .alt_b?          then move_word_backward
        in .ctrl_c?         then on_ctrl_c
        in .eof?, .ctrl_d?, .ctrl_x?
          output.puts
          return nil
        end

        if read.is_a?(CharReader::Sequence) && (read.tab? || read.enter? || read.alt_enter? || read.shift_tab? || read.escape? || read.back? || read.ctrl_c?)
        else
          if @auto_completion.open?
            auto_complete_insert_char(read)
            @editor.update
          end
        end
      end
    end

    def read_loop(& : String -> _)
      loop do
        yield read_next || break
      end
    end

    # Reset the line number and close auto-completion results.
    def reset
      @line_number = 1
      @auto_completion.close
    end

    private def on_char(char)
      @editor.update do
        @editor << char
        line = @editor.current_line.rstrip(' ')

        if @editor.x == line.size
          # Re-indent line after typing a char.
          if shift = self.reindent_line(line)
            indent = self.indentation_level(@editor.expression_before_cursor)
            new_indent = (indent + shift).clamp 0..
            @editor.current_line = "  "*new_indent + @editor.current_line.lstrip(' ')
          end
        end
      end
    end

    private def on_string(string)
      @editor.update do
        @editor << string
      end
    end

    private def on_enter(alt_enter = false, &)
      @auto_completion.close
      if alt_enter || (@editor.cursor_on_last_line? && continue?(@editor.expression))
        @editor.update do
          insert_new_line(indent: self.indentation_level(@editor.expression_before_cursor))
        end
      else
        submit_expr
        yield @editor.expression
      end
    end

    private def on_up
      has_moved = @editor.move_cursor_up

      if !has_moved && (new_lines = @history.up(@editor.lines))
        @editor.replace(new_lines)
        @editor.move_cursor_to_end
      end
    end

    private def on_down
      has_moved = @editor.move_cursor_down

      if !has_moved && (new_lines = @history.down(@editor.lines))
        @editor.replace(new_lines)
        @editor.move_cursor_to_end_of_line(y: 0)
      end
    end

    private def on_left
      @editor.move_cursor_left
    end

    private def on_right
      @editor.move_cursor_right
    end

    private def on_back
      auto_complete_remove_char if @auto_completion.open?
      @editor.update { back }
    end

    # If overridden, can yield an expression to giveback to `run`.
    # This is made because the `PryInterface` in `IC` can override these hotkeys and yield
    # command like `step`/`next`.
    #
    # TODO: It need a proper design to override hotkeys.
    private def on_ctrl_up(& : String ->)
      @editor.scroll_down
    end

    private def on_ctrl_down(& : String ->)
      @editor.scroll_up
    end

    private def on_ctrl_left(& : String ->)
      move_word_backward
    end

    private def on_ctrl_right(& : String ->)
      move_word_forward
    end

    private def on_delete
      @editor.update { delete }
    end

    private def on_ctrl_c
      @auto_completion.close
      @editor.end_editing
      output.puts "^C"
      @history.set_to_last
      @editor.prompt_next
    end

    private def on_tab(shift_tab = false)
      line = @editor.current_line

      # Retrieve the word under the cursor
      word_begin, word_end = self.current_word_begin_end
      current_word = line[word_begin..word_end]

      if @auto_completion.open?
        if shift_tab
          replacement = @auto_completion.selection_previous
        else
          replacement = @auto_completion.selection_next
        end
      else
        # Get whole expression before cursor, allow auto-completion to deduce the receiver type
        expr = @editor.expression_before_cursor(x: word_begin)

        # Compute auto-completion, return `replacement` (`nil` if no entry, full name if only one entry, or the begin match of entries otherwise)
        replacement = @auto_completion.complete_on(current_word, expr)

        if replacement && @auto_completion.entries.size >= 2
          @auto_completion.open
        end
      end

      if replacement
        @editor.update do
          # Replace the current_word by the replacement word:
          @editor.current_line = line.sub(word_begin..word_end, replacement)
        end

        # Move cursor:
        @editor.move_cursor_to(x: word_begin + replacement.size, y: @editor.y)
      end
    end

    private def on_escape
      @auto_completion.close
      @editor.update
    end

    private def on_begin
      @editor.move_cursor_to_begin
    end

    private def on_end
      @editor.move_cursor_to_end
    end

    private def auto_complete_insert_char(read)
      if read.is_a? Char && word_char?(@editor.x - 1)
        @auto_completion.name_filter = self.current_word
      elsif @editor.expression_scrolled? || read.is_a?(String)
        @auto_completion.close
      else
        @auto_completion.clear
      end
    end

    private def auto_complete_remove_char
      if word_char?(@editor.x - 1)
        @auto_completion.name_filter = self.current_word[...-1]
      else
        @auto_completion.clear
      end
    end

    def move_word_forward
      @editor.move_cursor_right if @editor.x == @editor.current_line.size

      word_end = self.next_word_end
      @editor.move_cursor_to(x: word_end + 1, y: @editor.y)
    end

    def move_word_backward
      @editor.move_cursor_left if @editor.x == 0

      word_begin = self.previous_word_begin
      @editor.move_cursor_to(x: word_begin, y: @editor.y)
    end

    def delete_char
      # TODO Ctrl-d
    end

    def delete_word
      # TODO Alt-d
    end

    def back
      # TODO backspace
    end

    def word_back
      # TODO Alt-backspace
    end

    def delete_after
      x = @editor.x
      if x == @editor.current_line.size
        @editor.update { @editor.delete }
      elsif !@editor.current_line.empty?
        editor.update do
          @editor.current_line = @editor.current_line[...x]
        end
      end
    end

    def delete_before
      x = @editor.x
      if x == 0
        @editor.update { @editor.back }
      elsif !@editor.current_line.empty?
        @editor.update do
          @editor.current_line = @editor.current_line[x..]
        end

        @editor.move_cursor_to(x: 0, y: @editor.y)
      end
    end

    private def next_word_end
      x = @editor.x
      while word_char?(x) == false
        x += 1
      end

      while word_char?(x)
        x += 1
      end
      x - 1
    end

    private def previous_word_begin
      x = @editor.x - 1
      while word_char?(x) == false
        x -= 1
      end

      while word_char?(x)
        x -= 1
      end
      x + 1
    end

    private def current_word_begin_end(x = @editor.x)
      word_begin = {x - 1, 0}.max
      word_end = x
      while word_char?(word_begin)
        word_begin -= 1
      end

      while word_char?(word_end)
        word_end += 1
      end

      {word_begin + 1, word_end - 1}
    end

    private def current_word
      word_begin, word_end = self.current_word_begin_end

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
