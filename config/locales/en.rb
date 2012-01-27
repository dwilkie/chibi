{
  :en => {
    :messages => {
      :new_chat_started => lambda {|key, options|
        users_name = " #{options[:users_name]}" if options[:users_name]
        friends_screen_name = options[:friends_screen_name]
        greeting = "Hi"
        greeting << users_name.capitalize if users_name
        introduction = options[:to_user] ? "U r now chatting with #{friends_screen_name}" : "#{friends_screen_name} wants 2 chat with u"
        greeting << "! " << introduction << "! " << "Send #{friends_screen_name} a msg now or reply with 'new' 2 chat with someone new"
      }
    }
  }
}
