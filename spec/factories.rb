require "#{Rails.root}/spec/support/phone_call_helpers"
require "#{Rails.root}/spec/support/mobile_phone_helpers"

FactoryGirl.define do

  trait :from_last_month do
    created_at {1.month.ago}
  end

  factory :message do
    user
    from { user.mobile_number }

    factory :message_from_last_month do
      from_last_month
    end
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

    sequence(:mobile_number, 85597000000) {|n| n.to_s }
    location

    factory :user_with_recent_interaction do
      after(:create) do |user|
        FactoryGirl.create(:phone_call, :user => user)
        FactoryGirl.create(:message, :user => user)
        FactoryGirl.create(:reply, :user => user)
      end
    end

    factory :user_without_recent_interaction do
      after(:create) do |user|
        FactoryGirl.create(:phone_call, :user => user, :created_at => 5.days.ago)
        FactoryGirl.create(:message, :user => user, :created_at => 5.days.ago)
        FactoryGirl.create(:reply, :user => user, :created_at => 5.days.ago)
      end
    end

    factory :user_from_last_month do
      from_last_month
    end

    factory :offline_user do
      online false
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
    end

    factory :jamie do
      name "jamie"
      updated_at { 15.minutes.ago }
    end

    # user with unknown gender
    factory :chamroune do
      name "chamroune"
      looking_for "f"
    end

    # bisexual with unknown gender
    factory :reaksmey do
      name "reaksmey"
      looking_for "e"
      updated_at { 15.minutes.ago }
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
        association :location, :factory => :siem_reap
        updated_at { 15.minutes.ago }
      end

      factory :paul do
        name "paul"
        age 39
        updated_at { 30.minutes.ago }
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
      updated_at 15.minutes.ago
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
