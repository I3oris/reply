module Reply
  class Search
    getter? open = false
    property query = ""
    getter? failed = false

    def footer(io : IO, color? : Bool)
      if open?
        io << "search: #{@query.colorize.toggle(failed? && color?).bold.red}_"
        1
      else
        0
      end
    end

    def open
      @open = true
      @failed = false
    end

    def close
      @open = false
      @query = ""
    end

    def search(history, from_index = history.index)
      index, x, y = history.search_up(@query, from_index: from_index)
      if index
        @failed = false
        result = history.go_to index
        return result, x, y
      end

      @failed = true
      history.set_to_last
      return nil, 0, 0
    end
  end
end
