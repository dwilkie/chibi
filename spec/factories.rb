FactoryGirl.define do
  factory :chat do
    association :user, :factory => :registered_user
    association :friend, :factory => :registered_user
  end

  factory :active_chat, :parent => :chat do
    after_create do |chat|
      chat.active_users << chat.user
      chat.active_users << chat.friend
      chat.save
    end
  end

  factory :location do
    country_code "KH"
  end

  factory :user do
    sequence(:mobile_number, 85597000000) {|n| n.to_s }

    factory :user_with_complete_profile do
      name "mara"
      date_of_birth Time.now
      gender "f"
      looking_for "m"
      location
    end
  end
end

