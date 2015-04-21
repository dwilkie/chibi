class Hash
  def underscorify_keys
    (transform_keys { |key| key.to_s.underscore }).with_indifferent_access
  end

  def integerify
    result = self.class.new
    each_key do |key|
      result[key.to_i] = self[key].to_i
    end
    result
  end
end
