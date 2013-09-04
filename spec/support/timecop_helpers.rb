module TimecopHelpers
  private

  def sometime_in(options)
    Time.new(options[:year], options[:month], (options[:day] || 1), 10, 5, 0)
  end
end
