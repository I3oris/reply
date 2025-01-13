require "./spec_helper"

module Reply
  describe Reader::Commands do
    it "executes method" do
      reader = SpecHelper.reader(type: SpecCommandReader)
      help_message = "method: \n"

      reader.run_commands("method")
      reader.output.to_s.should eq("executing method\n")

      reader.output = IO::Memory.new
      reader.run_commands("method a")
      reader.output.to_s.should eq(help_message)
    end

    it "executes method with single argument" do
      reader = SpecHelper.reader(type: SpecCommandReader)
      help_message = "method_with_single_arg: Help summary\n"

      reader.run_commands("method_with_single_arg")
      reader.output.to_s.should eq(help_message)

      reader.output = IO::Memory.new
      reader.run_commands("method_with_single_arg a")
      reader.output.to_s.should eq("executing method_with_single_arg, args: a\n")

      reader.output = IO::Memory.new
      reader.run_commands("method_with_single_arg a b")
      reader.output.to_s.should eq(help_message)
    end

    it "executes method with complex arguments" do
      reader = SpecHelper.reader(type: SpecCommandReader)
      help_message = "method_with_complex_args: Help summary\n" + "Help details\n"

      reader.run_commands("method_with_complex_args")
      reader.output.to_s.should eq(help_message)

      reader.output = IO::Memory.new
      reader.run_commands("method_with_complex_args a")
      reader.output.to_s.should eq(help_message)

      reader.output = IO::Memory.new
      reader.run_commands("method_with_complex_args a b")
      reader.output.to_s.should eq("executing method_with_complex_args, args: a b nil foo nil\n")

      reader.output = IO::Memory.new
      reader.run_commands("method_with_complex_args a b c")
      reader.output.to_s.should eq("executing method_with_complex_args, args: a b c foo nil\n")

      reader.output = IO::Memory.new
      reader.run_commands("method_with_complex_args a b c d")
      reader.output.to_s.should eq("executing method_with_complex_args, args: a b c d nil\n")

      reader.output = IO::Memory.new
      reader.run_commands("method_with_complex_args a b c d e")
      reader.output.to_s.should eq("executing method_with_complex_args, args: a b c d e\n")

      reader.output = IO::Memory.new
      reader.run_commands("method_with_complex_args a b c d e f")
      reader.output.to_s.should eq("executing method_with_complex_args, args: a b c d e f\n")

      reader.output = IO::Memory.new
      reader.run_commands("method_with_complex_args a b c d e f g")
      reader.output.to_s.should eq("executing method_with_complex_args, args: a b c d e f g\n")
    end

    it "exits on annotation Exit" do
      reader = SpecHelper.reader(type: SpecCommandReader)

      result = reader.run_commands("exit_method")
      reader.output.to_s.should eq("executing exit_method\n")
      reader.exit_result?(result).should be_true
    end

    it "parses command arguments" do
      reader = SpecHelper.reader(type: SpecCommandReader)
      command, arguments = reader.parse_command("command foo bar baz")
      command.should eq "command"
      arguments.should eq ["foo", "bar", "baz"]

      command, arguments = reader.parse_command(%(  command   foo   "bar' baz'"  'bam"' 💎! --foo-bar="baz" '' -abc))
      command.should eq "command"
      arguments.should eq [%(foo), %("bar' baz'"), %('bam"'), %(💎!), %(--foo-bar="baz"), %(''), %(-abc)]
      arguments.size.should eq 7
    end
  end
end
