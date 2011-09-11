class String
  AddressRegexp = %r(^(.*?)://(.*?)$)

  def with_sms_protocol
    "sms://#{without_protocol}"
  end

  def without_protocol
    self =~ AddressRegexp ? $2 : self
  end
end
