FactoryGirl.define do
  factory :message do
    user
    from { user.mobile_number }
  end

  factory :reply do
    user
    to { user.mobile_number }
  end

  factory :chat do
    association :user, :factory => :user
    association :friend, :factory => :user
  end

  factory :active_chat, :parent => :chat do
    after_create do |chat|
      chat.active_users << chat.user
      chat.active_users << chat.friend
      chat.save
    end

    factory :active_chat_with_inactivity do
      updated_at { 10.minutes.ago }
    end
  end

  factory :location do
    country_code "KH"

    factory :cambodia do
      country_code "KH"

      factory :phnom_penh do
        city "Phnom Penh"
        latitude 11.558831
        longitude 104.917445
      end

      factory :siem_reap do
        city "Siem Reap"
        latitude 13.3622222
        longitude 103.8597222
      end

      factory :battambang do
        city "Battambang"
        latitude 13.1
        longitude 103.2
      end
    end

    factory :thailand do
      country_code "TH"

      factory :chiang_mai do
        city "Samoeng"
        latitude 18.7964642
        longitude 98.6600586
      end
    end

    factory :england do
      country_code "EN"

      factory :london do
        city "London"
        latitude 51.5081289
        longitude -0.128005
      end
    end

    factory :united_states do
      country_code "US"

      factory :new_york do
        city "New York"
        latitude 40.7143528
        longitude -74.00597309999999
      end
    end
  end

  factory :user do
    sequence(:mobile_number, 85597000000) {|n| n.to_s }
    location

    factory :offline_user do
      online false
    end

    factory :user_with_name do
      name "veronica"

      factory :user_with_complete_profile do
        date_of_birth { 23.years.ago }
        gender "f"
        looking_for "m"
        association :location, :factory => :phnom_penh

        factory :english_user_with_complete_profile do
          association :location, :factory => :london
        end
      end
    end

    factory :cambodian do
      association :location, :factory => :cambodia
    end

    factory :english do
      association :location, :factory => :england
    end

    # do not reorder these factories because the tests rely on
    # the order so they fail when match statements are left off

    # users with unknown details
    factory :alex do
      name "alex"
    end

    factory :jamie do
      name "jamie"
    end

    # user with unknown gender
    factory :chamroune do
      name "chamroune"
      looking_for "f"
    end

    # user with unknown looking for preference
    factory :pauline do
      name "pauline"
      gender "f"
    end

    # straight girls
    factory :nok do
      name "nok"
      gender "f"
      looking_for "m"
      association :location, :factory => :chiang_mai

      factory :joy do
        name "joy"
        age 27
        association :location, :factory => :phnom_penh
      end
    end

    # straight guys
    factory :dave do
      name "dave"
      gender "m"
      looking_for "f"
      age 28
      association :location, :factory => :phnom_penh

      factory :con do
        name "con"
        age 37
      end

      factory :paul do
        name "paul"
        age 39
      end

      factory :luke do
        name "luke"
        age 25
      end
    end

    # lesbians
    factory :harriet do
      name "harriet"
      gender "f"
      looking_for "f"
      association :location, :factory => :battambang

      factory :eva do
        name "eva"
        association :location, :factory => :siem_reap
      end
    end

    # gays
    factory :hanh do
      name "hanh"
      gender "m"
      looking_for "m"
      age 28
      association :location, :factory => :chiang_mai

      factory :view do
        name "view"
        age 26
      end
    end

    # bi girl
    factory :mara do
      name "mara"
      gender "f"
      looking_for "e"
      age 25
      association :location, :factory => :phnom_penh
    end

    # bi guy
    factory :michael do
      name "michael"
      gender "m"
      looking_for "e"
      age 29
      association :location, :factory => :chiang_mai
    end
  end
end
