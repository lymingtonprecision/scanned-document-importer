class Time
  unless method_defined? :to_date
    def to_date
      Date.new(year, month, day)
    end
  end
end

class DateTime
  unless method_defined? :to_date
    def to_date
      Date.new(year, month, day)
    end
  end
end
