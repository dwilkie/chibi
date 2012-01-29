{
  :en => {
    :messages => {
      :new_chat_started => lambda {|key, options|
        friends_screen_name = options[:friends_screen_name]
        greeting = "Hi"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]
        introduction = options[:to_user] ? "U r now chatting with #{friends_screen_name}" : "#{friends_screen_name} wants 2 chat with u"
        greeting << "! " << introduction << "! " << "Send #{friends_screen_name} a msg now or reply with 'new' 2 chat with someone new"
      },

      :could_not_start_new_chat => lambda {|key, options|
        greeting = "Hi"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]
        greeting << ", we can't find a match for u at this time. We'll let u know when someone comes online!"
      }
    }
  }
}
