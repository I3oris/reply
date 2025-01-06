require "./spec_helper"
require "../src/reader"
require "../src/do_methods"

class MyRepl < Reply::Reader
  @[Reply::Help("This is a test command")]
  def do_test(arg : String)
    # do nothing
    false
  end

  include Reply::DoMethods
  class_property commands # for test accessibility

  def verify_commands
    test_cmd = @@commands["test"]
    test_cmd.doc.should eq "This is a test command"
    test_cmd.action.call(self, "irrelevant").should be_false

    help_cmd = @@commands["help"]
    help_cmd.doc.should eq "Print help for each command. Specify help [command] for help on a specific command"
    help_cmd.action.call(self, "").should be_false
  end
end

describe Reply::DoMethods do
  it "loads the command info right" do
    MyRepl.new.verify_commands
  end
end