class SearchHandler < MessageHandler

  def process!
    extract_user_details

#    reply I18n.t(
#      "messages.new_match",
#      :match => User.match(user),
#      :name => user.name
#    )
  end

  private

  def extract_user_details
    stripped_body = self.body.dup

    # kjom sok 23chnam broh phnom penh jong rok mit srey

    profile_complete = user.profile_complete?

    extract_date_of_birth(stripped_body, profile_complete)
    extract_name(stripped_body, profile_complete)
  end

  def extract_date_of_birth(body, force_update)
    match = strip_match!(body, /(\d{2})\s*(chnam|yo)?/)[1]
    user.age = match.to_i if match && (force_update || user.date_of_birth.nil?)
  end

  def extract_name(body, force_update)
    match = strip_match!(body, /\A(im|i'm|m|kjom|nhom|nyom|knhom|knyom)?\s*(\b\w+\b)/i)[2]
    user.name = match.downcase if match && (force_update || user.name.nil?)
  end

  def extract_gender(body, force_update)
    # test cases:

    # want girl friend
    # want girlfriend
    # jong rok mit srey
    # kjom broh jong rok mit srey

    # if there's 1 gender, then assume that's what the user is looking for
    # if there's 2 genders then the first one is their gender, 2nd is what their looking for
    # if they say *friend* without a gender then they r looking for a friend (don't know gender)
    # if they say gender + *friend* or *friend* + gender they're looking for that gender
    # keywords: girlfriend, boyfriend, friend, srey, broh, girl, boy, \bm\b, \bf\b, man, woman, bf, gf, bfriend, gfriend
    match = strip_match!(body, /||/)

  end

  def strip_match!(body, regexp)
    body.gsub!(regexp, "")
    body.strip!
    $~
  end

end

