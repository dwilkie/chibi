class Hash
  def underscorify_keys!
    keys.each do |key|
      self[key.to_s.underscore.to_sym] = delete(key)
    end
    self
  end

  def integerify_keys!
    keys.each do |key|
      self[key.to_i] = delete(key)
    end
    self
  end
end
