{
  :en => {
    :messages => {
      :suggestions => lambda {|key, options|
        sex = options[:looking_for] ? I18n.t(options[:looking_for]) : "body"
        options[:usernames].empty? ? "Sorry I don't know any #{sex}" : "I know #{options[:usernames].size} #{sex}: #{options[:usernames].join(', ')}. e.g. to chat with #{options[:usernames].first} text hello #{options[:usernames].first} how are you?"
      }
    }
  }
}

