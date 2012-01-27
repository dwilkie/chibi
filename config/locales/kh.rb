{
  :kh => {
    :messages => {
      :new_chat_started => lambda {|key, options|
        users_name = " #{options[:users_name]}" if options[:users_name]
        friends_screen_name = options[:friends_screen_name]
        greeting = "Sousdey"
        greeting << users_name.capitalize if users_name
        introduction = options[:to_user] ? "Alow nih, bong jaap pdaum chat jea moy #{friends_screen_name} haey" : "#{friends_screen_name} jong chat jea moy"
        greeting << "! " << introduction << "! " << "Chleuy torb tov #{friends_screen_name} re ban-chhop chat doy sor-say 'new' rok mit tmey teat"
      },

      :could_not_start_new_chat => lambda {|key, options|
        users_name = " #{options[:users_name]}" if options[:users_name]
        greeting = "Sousdey"
        greeting << users_name.capitalize if users_name
        greeting << ", we can't find a match for u at this time. We'll let u know when someone comes online!"
      }
    }
  }
}
