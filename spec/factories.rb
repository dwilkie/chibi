require "#{Rails.root}/spec/support/phone_call_helpers"
require "#{Rails.root}/spec/support/mobile_phone_helpers"

FactoryGirl.define do

  trait :from_last_month do
    created_at {1.month.ago}
  end

  sequence :guid do |n|
    "296cba84-c82f-49c0-a732-a9b09815fbe#{n}"
  end

  sequence :token do |n|
    "123abc84-a82e-23a1-b691-b2c19834bce#{n}"
  end

  factory :message do
    user
    from { user.mobile_number }

    factory :message_from_last_month do
      from_last_month
    end

    factory :message_with_guid do
      guid
    end
  end

  factory :delivery_receipt do
    association :reply, :factory => :reply_with_token
    state { "delivered" }
    token { reply.token }
  end

  factory :missed_call do
    user
    subject { "You have a missed call from 0#{user.local_number}" }
  end

  factory :phone_call do

    user
    from { user.mobile_number }
    sequence(:sid)

    factory :phone_call_from_offline_user do
      association :user, :factory => :offline_user
    end

    factory :phone_call_with_active_chat do
      association :chat, :factory => :active_chat
      user { chat.user }
    end

    factory :phone_call_to_unavailable_user do
      before(:create) do |phone_call|
        chat = FactoryGirl.create(:active_chat_with_single_user)
        FactoryGirl.create(:active_chat, :user => chat.friend)
        phone_call.user = chat.user
      end
    end

    extend PhoneCallHelpers::States

    with_phone_call_states do |factory_name, twiml_expectation, phone_call_state, next_state, sub_factories, parent|
      factory_options = {}
      factory_options.merge!(:parent => parent) if parent

      factory(factory_name, factory_options) do
        state phone_call_state

        sub_factories.each do |sub_factory_name, substate_attributes|
          attribute_value_pair = substate_attributes.values.first["factory"]
          substate_parent = attribute_value_pair["parent"]
          sub_factory_options = {}
          sub_factory_options.merge!(:parent => substate_parent) if substate_parent
          factory(sub_factory_name, sub_factory_options) do
            if substate_parent
              state phone_call_state
            else
              send(attribute_value_pair.keys.first, *attribute_value_pair.values.first)
            end
          end
        end
      end
    end
  end

  factory :reply do
    user
    to { user.mobile_number }

    factory :reply_from_last_month do
      from_last_month
    end

    factory :reply_with_token do
      token
    end

    factory :reply_with_locale do
      locale { user.locale }

      factory :reply_with_alternate_translation do
        alternate_translation "alternate translation"

        factory :delivered_reply_with_alternate_translation do
          delivered_at { Time.now }

          factory :delivered_reply_with_alternate_translation_no_locale do
            locale nil
          end
        end
      end
    end

    factory :delivered_reply do
      delivered_at { Time.now }
    end
  end

  factory :chat do
    association :user, :factory => :user
    association :friend, :factory => :user

    # a chat where only the friend is active
    factory :active_chat_with_single_friend do
      after(:create) do |chat|
        chat.active_users << chat.friend
      end
    end

    factory :chat_with_user_searching_for_friend do
      association :user, :factory => :user_searching_for_friend

      # this factory is used to assert that an active chat
      # cannot exist with a searching user
      factory :active_chat_with_user_searching_for_friend do
        after(:create) do |chat|
          chat.active_users << chat.user
          chat.save
        end
      end
    end

    # a chat where only the initator is active
    factory :active_chat_with_single_user do
      after(:create) do |chat|
        chat.active_users << chat.user
        chat.save
      end

      factory :active_chat_with_single_user_with_inactivity do
        updated_at { 10.minutes.ago }
      end

      factory :active_chat do
        after(:create) do |chat|
          chat.active_users << chat.friend
          chat.save
        end

        factory :active_chat_with_inactivity do
          updated_at { 10.minutes.ago }
        end
      end
    end
  end

  factory :location do
    country_code "kh"

    factory :cambodia do
      country_code "kh"

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
      country_code "th"

      factory :chiang_mai do
        city "Samoeng"
        latitude 18.7964642
        longitude 98.6600586
      end
    end

    factory :england do
      country_code "gb"

      factory :london do
        city "London"
        latitude 51.5081289
        longitude -0.128005
      end
    end

    factory :united_states do
      country_code "us"

      factory :new_york do
        city "New York"
        latitude 40.7143528
        longitude -74.00597309999999
      end
    end
  end

  factory :user do
    trait :without_recent_interaction do
      created_at { 5.days.ago }
      updated_at { 5.days.ago }
    end

    trait :without_recent_interaction_for_a_longer_time do
      created_at { 5.days.ago }
      updated_at { 6.days.ago }
    end

    trait :with_a_semi_recent_message do
      after(:create) do |user|
        FactoryGirl.create(:message, :user => user, :created_at => 15.minutes.ago)
      end
    end

    trait :with_a_recent_phone_call do
      after(:create) do |user|
        FactoryGirl.create(:phone_call, :user => user)
      end
    end

    sequence(:mobile_number, 85597000000) {|n| n.to_s }
    location

    factory :user_searching_for_friend do
      state "searching_for_friend"
    end

    factory :user_without_recent_interaction do
      without_recent_interaction
    end

    factory :user_from_registered_service_provider do
      sequence(:mobile_number, 85510000000) {|n| n.to_s }

      factory :user_from_registered_service_provider_without_recent_interaction do
        without_recent_interaction
      end

      factory :user_from_registered_service_provider_without_recent_interaction_for_a_longer_time do
        without_recent_interaction_for_a_longer_time
      end
    end

    factory :user_from_last_month do
      from_last_month
    end

    factory :offline_user do
      state "offline"
    end

    factory :male_user do
      gender "m"
    end

    factory :female_user do
      gender "f"
    end

    factory :user_with_invalid_mobile_number do
      sequence(:mobile_number, 8551234) {|n| n.to_s }
    end

    factory :user_with_invalid_gender do
      gender "e"
    end

    factory :user_with_invalid_looking_for_preference do
      looking_for 3
    end

    factory :user_who_is_too_old do
      age 100
    end

    factory :user_who_is_too_young do
      age 9
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

    factory :user_with_gender do
      gender "f"

      factory :user_with_gender_and_looking_for_preference do
        looking_for "m"
      end
    end

    factory :user_with_age do
      age 23
    end

    # do not reorder these factories because the tests rely on
    # the order so they fail when match statements are left off

    # users with unknown details
    factory :alex do
      name "alex"
      with_a_recent_phone_call
    end

    factory :jamie do
      name "jamie"
      with_a_semi_recent_message
    end

    # user with unknown gender
    factory :chamroune do
      name "chamroune"
      looking_for "f"
      with_a_recent_phone_call
    end

    # bisexual with unknown gender
    factory :reaksmey do
      name "reaksmey"
      looking_for "e"
      with_a_semi_recent_message
    end

    # user with unknown looking for preference
    factory :pauline do
      name "pauline"
      gender "f"
      with_a_recent_phone_call
    end

    # user with known age but unknown gender
    factory :kris do
      name "kris"
      age 25
      with_a_semi_recent_message
    end

    # straight girls
    factory :nok do
      name "nok"
      gender "f"
      looking_for "m"
      association :location, :factory => :chiang_mai
      with_a_semi_recent_message

      factory :joy do
        name "joy"
        age 27
        association :location, :factory => :phnom_penh
      end
    end

    # straight guys
    factory :paul do
      name "paul"
      age 39
      gender "m"
      looking_for "f"
      association :location, :factory => :phnom_penh
      with_a_semi_recent_message

      factory :con do
        name "con"
        age 37
        association :location, :factory => :siem_reap
      end

      factory :dave do
        name "dave"
        age 28
        with_a_recent_phone_call
      end

      factory :luke do
        name "luke"
        age 25
        with_a_recent_phone_call
      end
    end

    # lesbians
    factory :harriet do
      name "harriet"
      gender "f"
      looking_for "f"
      association :location, :factory => :battambang
      with_a_semi_recent_message

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
      with_a_semi_recent_message

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
      with_a_semi_recent_message
    end

    # bi guy
    factory :michael do
      name "michael"
      gender "m"
      looking_for "e"
      age 29
      with_a_semi_recent_message
      association :location, :factory => :chiang_mai
    end
  end

  extend MobilePhoneHelpers

  with_users_from_different_countries do |country_code, country_prefix, country_name, factory_name|
    factory(factory_name, :class => User) do
      sequence(:mobile_number) {|n| "#{country_prefix}00000000#{n}" }
      association :location, :factory => country_name
    end
  end

  with_service_providers do |service_provider, prefix, short_code, factory_name|
    factory(factory_name, :class => User) do
      sequence(:mobile_number) {|n| "#{prefix}000000#{n}" }
    end
  end
end
