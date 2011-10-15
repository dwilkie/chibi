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

    profile_complete = user.profile_complete?

    extract_gender_and_looking_for(stripped_body, profile_complete)
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

  def includes_gender_and_looking_for?(body)
    tmp_body = body.dup
    if sex = gender(tmp_body, :only_first => true)
      if wants = looking_for(tmp_body, :use_only_shared_gender_words => true)
        user.gender = sex
        user.looking_for = wants
        body = tmp_body
      end
    end
  end

  def extract_gender_and_looking_for(body, force_update)
    unless includes_gender_and_looking_for?(body)
      extract_looking_for(body)
      extract_gender(body, force_update)
    end
  end

  def extract_looking_for(body)
    user.looking_for = looking_for(body)
  end

  def extract_gender(body, force_update)
    user.gender = gender(body)
  end

  def looking_for(body, options = {})
    if looking_for_female?(body, options)
      "f"
    elsif looking_for_male?(body, options)
      "m"
    elsif !options[:use_only_shared_gender_words] && looking_for_friend?(body)
      "e"
    end
  end

  def gender(body, options = {})
    text = options[:only_first] ? includes_gender?(body, options).try(:[], 0).to_s : body

    if from_female?(text, options)
      "f"
    elsif from_male?(text, options)
      "m"
    end
  end

  def looking_for_female?(body, options = {})
    regexp = options[:use_only_shared_gender_words] ? /\b(girl|srey)\b/i : /\b(girlfriend|gf|friend girl|girl friend|met srey|mit srey)\b/i
    strip_match!(body, regexp)
  end

  def looking_for_male?(body, options = {})
    regexp = options[:use_only_shared_gender_words] ? /\b(boy|bros|pros)\b/i : /\b(boyfriend|bf|friend boy|boy friend|met bros|met pros|mit bros|mit pros)\b/i
    strip_match!(body, regexp)
  end

  def looking_for_friend?(body)
    strip_match!(body, /\b(friend|mit|met)\b/i)
  end

  def includes_gender?(body, options)
    strip_match!(body, /\b(srey|girl|f|female|pros|bros|m|male|boy)\b/i, options)
  end

  def from_female?(body, options = {})
    strip_match!(body, /\b(srey|girl|f|female)\b/i, options)
  end

  def from_male?(body, options = {})
    strip_match!(body, /\b(pros|bros|m|male|boy)\b/i, options)
  end

  def strip_match!(body, regexp, options = {})
    options[:only_first] ? body.sub!(regexp, "") : body.gsub!(regexp, "")
    body.strip!
    $~
  end

end

