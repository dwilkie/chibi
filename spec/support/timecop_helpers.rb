module TimecopHelpers
  private

  def at_time(hours, minutes = 0, &block)
    Timecop.freeze(Time.zone.local(2015, 10, 22, hours, minutes)) do
      yield
    end
  end

  def sometime_in(options)
    Time.zone.local(options[:year], options[:month], (options[:day] || 1), 10, 5, 0)
  end
end
