require "./spec_helper"

module Reply
  ENTRIES = [
    [%(puts "Hello World")],
    [%(i = 0)],
    [
      %(while i < 10),
      %(  puts i),
      %(  i += 1),
      %(end),
    ],
  ]

  describe History do
    it "submits entry" do
      history = SpecHelper.history

      history.verify([] of Array(String), index: 0)

      history << [%(puts "Hello World")]
      history.verify(ENTRIES[0...1], index: 1)

      history << [%(i = 0)]
      history.verify(ENTRIES[0...2], index: 2)

      history << [
        %(while i < 10),
        %(  puts i),
        %(  i += 1),
        %(end),
      ]
      history.verify(ENTRIES, index: 3)
    end

    it "submit dupplicate entry" do
      history = SpecHelper.history(with: ENTRIES)

      history.verify(ENTRIES, index: 3)

      history << [%(i = 0)]
      history.verify([ENTRIES[0], ENTRIES[2], ENTRIES[1]], index: 3)
    end

    it "clears" do
      history = SpecHelper.history(with: ENTRIES)

      history.clear
      history.verify([] of Array(String), index: 0)
    end

    it "navigates" do
      history = SpecHelper.history(with: ENTRIES)

      history.verify(ENTRIES, index: 3)

      # Before down: current edition...
      # After down: current edition...
      history.down(["current edition..."]) do
        raise "Should not yield"
      end.should be_nil
      history.verify(ENTRIES, index: 3)

      # Before up: current edition...
      # After up: while i < 10
      #  puts i
      #  i += 1
      # end
      history.up(["current edition..."]) do |entry|
        entry
      end.should eq ENTRIES[2]
      history.verify(ENTRIES, index: 2)

      # Before up: while i < 10
      #  puts i
      #  i += 1
      # end
      # After up: i = 0
      history.up(ENTRIES[2]) do |entry|
        entry
      end.should eq ENTRIES[1]
      history.verify(ENTRIES, index: 1)

      # Before up (edited): edited_i = 0
      # After up: puts "Hello World"
      history.up([%(edited_i = 0)]) do |entry|
        entry
      end.should eq ENTRIES[0]
      history.verify(ENTRIES, index: 0)

      # Before up: puts "Hello World"
      # After up: puts "Hello World"
      history.up(ENTRIES[0]) do
        raise "Should not yield"
      end.should be_nil
      history.verify(ENTRIES, index: 0)

      # Before down: puts "Hello World"
      # After down: edited_i = 0
      history.down(ENTRIES[0]) do |entry|
        entry
      end.should eq [%(edited_i = 0)]
      history.verify(ENTRIES, index: 1)

      # Before down down: edited_i = 0
      # After down down: current edition...
      history.down([%(edited_i = 0)], &.itself).should eq ENTRIES[2]
      history.down(ENTRIES[2], &.itself).should eq [%(current edition...)]
      history.verify(ENTRIES, index: 3)
    end
  end
end
