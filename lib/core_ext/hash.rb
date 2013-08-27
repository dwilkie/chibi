class Hash
  def underscorify_keys!
    keys.each do |key|
      self[key.to_s.underscore.to_sym] = delete(key)
    end
    self
  end

  def integerify!
    dup.each do |key, value|
      self[key.to_i] = delete(key).to_i
    end
    self
  end
end
