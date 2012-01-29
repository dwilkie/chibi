{
  :kh => {
    :messages => {
      :new_chat_started => lambda {|key, options|
        friends_screen_name = options[:friends_screen_name]
        greeting = "Sousdey"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]
        introduction = options[:to_user] ? "Pel nis nek jaap pderm chat jea moy #{friends_screen_name} haey" : "#{friends_screen_name} jong chat jea moy"
        greeting << "! " << introduction << "! " << "Chleuy torb tov #{friends_screen_name} re ban-chhop chat doy sor-say 'new' rok mit tmey teat"
      },

      :could_not_start_new_chat => lambda {|key, options|
        greeting = "Sousdey"
        greeting << " #{options[:users_name].capitalize}" if options[:users_name]
        greeting << ", som-tos pel nis min mean nek tom-nae. Yerng neng pjeur tov nek ma-dong teat nov pel mean nek tom-nae"
      }
    }
  }
}
