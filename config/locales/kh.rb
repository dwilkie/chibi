{
  :kh => {
    :messages => {
      :suggestions => lambda {|key, options|
        sex = options[:looking_for] ? I18n.t(options[:looking_for]) : "monu"
        options[:usernames].empty? ? "som to bong, nhom ot skual #{sex} te" : "nhom skual #{sex} #{options[:usernames].size} nek: #{options[:usernames].join(', ')}. chat mui #{options[:usernames].first}"
      }
    }
  }
}

