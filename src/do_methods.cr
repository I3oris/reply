module Reply
  annotation Help
  end

  class DoCommand(R)
    property action : R, String -> Bool
    property doc : String?

    def initialize(@action : Proc(R, String, Bool), @doc : String?)
    end
  end

  module DoMethods
    def do_help(arg : String? = nil) : Bool?
      return true if @@commands.empty?
      if arg && !arg.empty?
        if cmd = @@commands[arg]
          puts "    #{arg}        #{cmd.doc}"
        else
          puts "Command '#{arg}' not found"
        end
      else
        puts "Available Commands:"
        longest_cmd = @@commands.keys.max_by(&.size).size
        @@commands.each do |name, command|
          puts "    #{name.rjust longest_cmd}        #{command.doc}"
        end
      end
      false
    end

    def cmdloop
      read_loop do |expr|
        command, arg = if expr.includes? ' '
                         expr.split ' ', limit: 2, remove_empty: true
                       else
                         {expr, ""}
                       end
        if cmd = @@commands[command]?
          if cmd.action.call self, arg
            exit
          end
        else
          puts "unknown command #{command}"
          puts "available commands are:"
          puts @@commands.keys.join '\n'
          do_help
        end
      end
    end

    macro included
      @@commands : Hash(String, ::Reply::DoCommand({{@type}})) = {
        "help" => ::Reply::DoCommand.new(
          action: ->(repl : {{@type}}, arg : String) { repl.do_help arg },
          doc: "Print help for each command. Specify help [command] for help on a specific command",
        )
      }
      {% for method in @type.methods %}
        {% if method.name.stringify.starts_with? "do_" %}
          %action = ->(repl : {{@type}}, arg : String) {
            repl.{{method.name}}(arg)
          }
          %doc = {% if ant = method.annotation(::Reply::Help) %}
            {{ant[0]}}
          {% else %}
            nil
          {% end %}
          @@commands[{{ method.name.stringify[3..] }}] = ::Reply::DoCommand.new %action, %doc
        {% end %}
      {% end %}
    end
  end
end
