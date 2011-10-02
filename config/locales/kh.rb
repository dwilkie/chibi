{
  :kh => {
    :messages => {
      :suggestions => lambda {|key, options|
        gender = options[:looking_for] ? I18n.t(options[:looking_for]) : "monu"
        options[:usernames].empty? ? "som to bong, nhom ot skual #{gender} te" : "nhom skual #{gender} #{options[:usernames].size} nek: #{options[:usernames].join(', ')}. chat mui #{options[:usernames].first}"
      }
    }
  }
}

