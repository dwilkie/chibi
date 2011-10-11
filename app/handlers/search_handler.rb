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

    extract_gender(stripped_body, profile_complete)
    extract_date_of_birth(stripped_body, profile_complete)
    extract_name(stripped_body, profile_complete)
  end

  def extract_date_of_birth(body, force_update)
    match = strip_match!(body, /(\d{2})\s*(chnam|yo)?/).try(:[], 1)
    user.age = match.to_i if match && (force_update || user.date_of_birth.nil?)
  end

  def extract_name(body, force_update)
    match = strip_match!(body, /\A(im|i'm|m|kjom|nhom|nyom|knhom|knyom)?\s*(\b\w+\b)/i).try(:[], 2)
    user.name = match.downcase if match && (force_update || user.name.nil?)
  end

  def extract_gender(body, force_update)
    if from_female?(body)
      user.gender = "f"
    elsif from_male?(body)
      user.gender = "m"
    end
  end

  def from_female?(body)
    match = strip_match!(body, /\b(srey|girl|f|female)\b/)
    match
  end

  def from_male?(body)
    match = strip_match!(body, /\b(bros|broh|m|male|boy)\b/)
    match
  end

  def strip_match!(body, regexp)
    body.gsub!(regexp, "")
    body.strip!
    $~
  end

end

