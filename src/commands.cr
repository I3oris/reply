require "string_scanner"

class Reply::Reader
  # Include this module to add the capability to parse and execute commands.
  #
  # The methods starting with `do_` will be treating as commands.
  #
  # `run_commands(expression)` will parse expression and execute command if the command match, elsewhere it shows an help message.
  #
  # ex:
  # ```
  # class MyReader < Reply::Reader
  #   include Commands
  #
  #   def do_method(arg1, arg2 = nil)
  #     puts "executing command 'method' with arguments: #{arg1} #{arg2}"
  #   end
  # end
  #
  # reader = MyReader.new
  # reader.read_loop do |expression|
  #   reader.run_commands(expression)
  # end
  # ```
  #
  # See `/examples/command_relp.cr` for more details.
  #
  module Commands
    private struct ExitResult
    end

    def initialize
      super
      self.word_delimiters = {{" \n\t".chars}}
    end

    # Executes a do_method if expression starts with 'method'.
    # Passes the rest of the expression as arguments to the do_method, separated by spaces
    # ex:
    # `run_command("method 1 2 3")` will run `do_method("1", "2", "3")`
    #
    # Shows a help message if arguments mismatch.
    #
    # Returns the result of executed do_method, if any.
    def run_commands(expression)
      command, arguments = parse_command(expression)

      if command == "help"
        return do_help(arguments.first?)
      end

      {% for method in @type.methods %}
        {% if method.name.stringify.starts_with? "do_" %}
          if command == {{method.name.stringify["do_".size..]}}
            {% unless method.splat_index %}
              if arguments.size > {{method.args.size}}
                return do_help(command)
              end
            {% end %}

            result = self.{{method.name}}(
              {% i = 0 %}
              {% for argument in method.args %}
                {% if i == method.splat_index %}
                  (arguments[{{i}}..]? || [] of String),
                {% elsif (argument.restriction && argument.restriction.resolve.nilable?) || !argument.default_value.is_a? Nop %}
                  (arguments[{{i}}]? || {{argument.default_value || nil}}),
                {% else %}
                  (arguments[{{i}}]? || return do_help(command)),
                {% end %}
                {% i += 1 %}
              {% end %}
            )
            return ({% if method.annotation(Exit) %} ExitResult.new {% else %} result {% end %})
          end
        {% end %}
      {% end %}

      unknown_command(command, arguments)
      nil
    end

    # Prompts and `run_commands` in loop.
    def run_commands_loop
      read_loop do |expression|
        unless expression.empty?
          exit = run_commands(expression)
          break if exit.is_a? ExitResult
        end
      end
    end

    # Returns the command names defined by do_method, as `Array(String)`
    macro command_names
      {{ ["help"] + @type.methods.map(&.name.stringify).select(&.starts_with? "do_").map(&.["do_".size..]) }}
    end

    # Returns the command documentations defined by `Help` annotation, as `Hash(String, {summary: String, details: String})`
    macro command_docs(help_doc = nil)
      {% help_doc ||= "Print help for each command. Specify help [command] for help on a specific command" %}
      {% begin %}
        {
          "help" => {summary: {{help_doc}}, details: nil},

          {% for method in @type.methods.select(&.name.stringify.starts_with? "do_") %}
            {% annot = method.annotation(Help) %}
            {{method.name.stringify["do_".size..]}} => {summary: {{annot ? annot[0] : nil}}, details:  {{annot ? annot[:details] : nil}} },
          {% end %}
        }
      {% end %}
    end

    # Override this method to customize help message.
    def do_help(command_name : String? = nil)
      docs = command_docs({{@def.annotation(Help) ? @def.annotation(Help)[0] : nil}})

      if command_name = command_name.presence
        if command_doc = docs[command_name]?
          output.puts "#{highlight(command_name)}: #{command_doc[:summary]}"
          output.puts command_doc[:details] if command_doc[:details]?
        else
          unknown_command(command_name, [] of String)
        end
      else
        longest_name = command_names.max_by(&.size)
        docs.each do |name, doc|
          output.print " "*(longest_name.size - name.size)
          output.puts "#{highlight(name)}: #{doc[:summary]}"
        end
      end
    end

    # Override this method to customize message on unknown command.
    def unknown_command(command_name : String, arguments : Array(String))
      output.puts "Unknown command: #{command_name}"
      output.print "Available commands are: "
      output.puts command_names.join(", ") { |cmd| highlight(cmd) }
      output.puts
      do_help
    end

    # Override this method to provide name completion for arguments to a command.
    def auto_complete_arguments(command_name : String, name_filter : String, expression_before : String) : {String, Array(String)}
      {"", [] of String}
    end

    # `Commands#auto_complete` (this method) matches the first command to the
    # commands defined by the do_methods, and hands off any subsequent
    # completion requests to `#auto_complete_arguments`.
    def auto_complete(name_filter : String, expression_before : String) : {String, Array(String)}
      if expression_before.empty? || expression_before == "help "
        {"Available commands", command_names}
      else
        command_name, _ = parse_command(expression_before)
        auto_complete_arguments command_name, name_filter, expression_before
      end
    end

    # Override this method to customize how command and arguments are parsed from expression.
    #
    # ameba:disable Metrics/CyclomaticComplexity
    def parse_command(expression : String) : {String, Array(String)}
      arguments = [] of String
      current_word = String::Builder.new
      in_double_quote = false
      in_quote = false

      expression.each_char do |char|
        current_word << char if char != ' ' || in_quote || in_double_quote

        case
        when in_quote
          if char == '\''
            in_quote = false
            arguments << current_word.to_s
            current_word = String::Builder.new
          end
        when in_double_quote
          if char == '"'
            in_double_quote = false
            arguments << current_word.to_s
            current_word = String::Builder.new
          end
        when char == ' '
          unless current_word.bytesize == 0
            arguments << current_word.to_s
            current_word = String::Builder.new
          end
        when char == '\''
          in_quote = true
        when char == '"'
          in_double_quote = true
        end
      end

      unless current_word.bytesize == 0
        arguments << current_word.to_s
      end
      command = arguments.shift

      return command, arguments
    end
  end

  # Add this annotation to a do_method to indicate help of a command.
  #
  # ex:
  # Help("Do something", details: "\nUsage: method <arg1> [arg2]")
  # def do_method(arg1, arg2 = nil)
  # end
  annotation Help
  end

  # Add this annotation to exit the prompt after executing the command.
  annotation Exit
  end
end
