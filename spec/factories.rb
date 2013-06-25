require "#{Rails.root}/spec/support/phone_call_helpers"
require "#{Rails.root}/spec/support/mobile_phone_helpers"

FactoryGirl.define do

  trait :from_last_month do
    created_at {1.month.ago}
  end

  trait :from_chat do
    chat
  end

  trait :from_chat_initiator do
    from_chat
    user { chat.user }
  end

  sequence :guid do |n|
    "296cba84-c82f-49c0-a732-a9b09815fbe#{n}"
  end

  sequence :token do |n|
    "123abc84-a82e-23a1-b691-b2c19834bce#{n}"
  end

  sequence :mobile_number, 85597000000 do |n|
    n.to_s
  end

  sequence :registered_operator_number, 85560000000 do |n|
    n.to_s
  end

  sequence :operator_number_with_voice, 85510000000 do |n|
    n.to_s
  end

  factory :message do
    user
    from { user.mobile_number }

    trait :with_guid do
      guid
    end

    trait :processed do
      state "processed"
    end

    trait :without_user do
      user nil
      from "85597000000"
    end
  end

  factory :delivery_receipt do
    association :reply, :delivered, :with_token
    delivered
    token { reply.token }

    trait :delivered do
      state "delivered"
    end

    trait :failed do
      state "failed"
    end

    trait :confirmed do
      state "confirmed"
    end
  end

  factory :missed_call do
    subject { "You have a missed call from 062000000" }
  end

  factory :phone_call do
    from { generate(:mobile_number) }
    sid { generate(:guid) }

    trait :answered do
      state "answered"
    end

    trait :welcoming_user do
      state "welcoming_user"
    end

    trait :offering_menu do
      state "offering_menu"
    end

    trait :asking_for_age_in_menu do
      state "asking_for_age_in_menu"
    end

    trait :asking_for_gender_in_menu do
      state "asking_for_gender_in_menu"
    end

    trait :asking_for_looking_for_in_menu do
      state "asking_for_looking_for_in_menu"
    end

    trait :finding_new_friends do
      state "finding_new_friends"
    end

    trait :dialing_friends do
      state "dialing_friends"
    end

    trait :connecting_user_with_friend do
      state "connecting_user_with_friend"
    end

    trait :telling_user_their_chat_has_ended do
      state "telling_user_their_chat_has_ended"
    end

    trait :telling_user_to_try_again_later do
      state "telling_user_to_try_again_later"
    end

    trait :completed do
      state "completed"
    end

    trait :caller_wants_menu do
      digits "8"
    end

    trait :already_in_chat do
      after(:create) do |phone_call|
        create(:chat, :active, :user => phone_call.user)
      end
    end

    trait :with_active_chat do
      after(:create) do |phone_call|
        chat = create(:chat, :active, :user => phone_call.user)
        phone_call.chat = chat
      end
    end

    trait :to_unavailable_user do
      after(:create) do |phone_call|
        chat = create(:chat, :initiator_active, :user => phone_call.user)
        create(:chat, :active, :user => chat.friend)
      end
    end

    trait :found_friends do
      after(:create) do |phone_call|
        create_list(
          :chat, 5, :friend_active, :user => phone_call.user, :starter => phone_call
        )
      end
    end

    trait :caller_is_24_years_old do
      digits "24"
    end

    trait :caller_answers_male do
      digits "1"
    end

    trait :caller_answers_female do
      digits "2"
    end

    trait :dial_status_completed do
      dial_status "completed"
    end

    trait :with_dial_call_sid do
      dial_call_sid { generate(:guid) }
    end

    trait :from_offline_user do
      association :user, :factory => [:user, :offline]
    end
  end

  factory :reply do
    user
    body "body"
    to { user.mobile_number }

    trait :delivered do
      delivered_at { Time.now }
    end

    trait :queued_for_smsc_delivery do
      state "queued_for_smsc_delivery"
    end

    trait :delivered_by_smsc do
      state "delivered_by_smsc"
    end

    trait :rejected do
      state "rejected"
    end

    trait :failed do
      state "failed"
    end

    trait :confirmed do
      state "confirmed"
    end

    trait :with_token do
      token
    end

    trait :with_unset_destination do
      to nil
    end

    trait :with_no_body do
      body nil
    end
  end

  factory :chat do
    association :user, :factory => :user
    association :friend, :factory => :user

    trait :with_user_searching_for_friend do
      association :user, :factory => [:user, :searching_for_friend]
    end

    trait :initiator_active do
      after(:create) do |chat|
        chat.active_users << chat.user
        chat.save
      end
    end

    trait :friend_active do
      after(:create) do |chat|
        chat.active_users << chat.friend
        chat.save
      end
    end

    trait :with_message do
      after(:create) do |chat|
        chat.messages << FactoryGirl.create(:message, :user => chat.friend)
      end
    end

    trait :active do
      initiator_active
      friend_active
    end

    trait :with_inactivity do
      updated_at { 10.minutes.ago }
    end
  end

  factory :location do
    country_code "kh"

    trait :cambodia do
      country_code "kh"
    end

    trait :thailand do
      country_code "th"
    end

    trait :england do
      country_code "gb"
    end

    trait :united_states do
      country_code "us"
    end

    trait :phnom_penh do
      cambodia
      city "Phnom Penh"
      latitude 11.558831
      longitude 104.917445
    end

    trait :siem_reap do
      cambodia
      city "Siem Reap"
      latitude 13.3622222
      longitude 103.8597222
    end

    trait :battambang do
      cambodia
      city "Battambang"
      latitude 13.1
      longitude 103.2
    end

    trait :chiang_mai do
      thailand
      city "Samoeng"
      latitude 18.7964642
      longitude 98.6600586
    end

    trait :london do
      england
      city "London"
      latitude 51.5081289
      longitude -0.128005
    end

    trait :new_york do
      united_states
      city "New York"
      latitude 40.7143528
      longitude -74.00597309999999
    end
  end

  factory :user do
    cambodian

    trait :without_recent_interaction do
      created_at { 6.days.ago }
      updated_at { 6.days.ago }
    end

    trait :without_recent_interaction_for_a_longer_time do
      created_at { 8.days.ago }
      updated_at { 7.days.ago }
    end

    trait :without_recent_interaction_for_a_shorter_time do
      created_at { 8.days.ago }
      updated_at { 3.days.ago }
    end

    trait :with_a_semi_recent_message do
      after(:create) do |user|
        FactoryGirl.create(:message, :user => user, :created_at => 15.minutes.ago)
        user.updated_at = 15.minutes.ago
        user.save!
      end
    end

    trait :with_a_recent_phone_call do
      after(:create) do |user|
        FactoryGirl.create(:phone_call, :user => user)
      end
    end

    trait :from_registered_service_provider do
      mobile_number { generate(:registered_operator_number) }
    end

    trait :from_operator_with_voice do
      mobile_number { generate(:operator_number_with_voice) }
    end

    trait :searching_for_friend do
      state "searching_for_friend"
    end

    trait :offline do
      state "offline"
    end

    trait :with_name do
      name "veronica"
    end

    trait :with_gender do
      female
    end

    trait :with_looking_for_preference do
      looking_for "m"
    end

    trait :with_location do
      association :location, :phnom_penh
    end

    trait :with_date_of_birth do
      date_of_birth { 23.years.ago }
    end

    trait :with_complete_profile do
      with_name
      with_date_of_birth
      with_gender
      with_looking_for_preference
      with_location
    end

    trait :from_england do
      association :location, :london
    end

    trait :male do
      gender "m"
    end

    trait :female do
      gender "f"
    end

    trait :with_invalid_mobile_number do
      sequence(:mobile_number, 8551234) {|n| n.to_s }
    end

    trait :with_invalid_gender do
      gender "e"
    end

    trait :with_invalid_looking_for_preference do
      looking_for 3
    end

    trait :too_young do
      age 9
    end

    trait :too_old do
      age 100
    end

    trait :cambodian do
      sequence(:mobile_number) { |n| "85597000000#{n}" }
    end

    trait :from_kampong_thom do
      sequence(:mobile_number) { |n| "85562000000#{n}" }
    end

    trait :from_phnom_penh do
      sequence(:mobile_number) { |n| "85523000000#{n}" }
    end

    trait :from_battambang do
      sequence(:mobile_number) { |n| "85553000000#{n}" }
    end

    trait :from_siem_reap do
      sequence(:mobile_number) { |n| "85563000000#{n}" }
    end

    trait :english do
      sequence(:mobile_number) { |n| "4412000000#{n}" }
    end

    trait :american do
      sequence(:mobile_number) { |n| "141600000#{n}" }
    end

    trait :thai do
      sequence(:mobile_number) { |n| "6689000000#{n}" }
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
      from_registered_service_provider
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
      with_a_semi_recent_message
      thai
      association :location, :chiang_mai

      factory :joy do
        name "joy"
        age 27
        cambodian
        association :location, :phnom_penh
      end
    end

    # straight guys
    factory :paul do
      name "paul"
      age 39
      gender "m"
      looking_for "f"
      with_a_semi_recent_message
      association :location, :phnom_penh

      factory :con do
        name "con"
        age 37
        association :location, :siem_reap
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
      with_a_semi_recent_message
      association :location, :battambang

      factory :eva do
        name "eva"
        association :location, :siem_reap
      end
    end

    # gays
    factory :hanh do
      name "hanh"
      gender "m"
      looking_for "m"
      age 28
      with_a_semi_recent_message
      thai
      association :location, :chiang_mai

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
      with_a_semi_recent_message
      association :location, :phnom_penh
    end

    # bi guy
    factory :michael do
      name "michael"
      gender "m"
      looking_for "e"
      age 29
      with_a_semi_recent_message
      thai
      association :location, :chiang_mai
    end
  end

  factory :call_data_record do
    ignore do
      variables false
      user_who_called nil
      user_who_was_called nil
      phone_call nil

      default_body <<-CDR
        <?xml version="1.0"?>
        <cdr core-uuid="fa2fc41d-ccc1-478b-99b8-4b90e74bb11d">
          <variables>
            <direction>inbound</direction>
            <uuid>some_uuid</uuid>
            <duration>20</duration>
            <billsec>15</billsec>
          </variables>
        </cdr>
      CDR
    end

    body do
      dynamic_body = MultiXml.parse(default_body)["cdr"]
      calling_user = user_who_called || FactoryGirl.create(:user)

      dynamic_variables = variables || {}

      dynamic_variables["direction"] ||= "inbound"
      dynamic_variables["duration"] ||= "20"
      dynamic_variables["billsec"] ||= "15"

      incoming_phone_call = phone_call || FactoryGirl.create(:phone_call, :user => calling_user)

      if dynamic_variables["direction"] == "inbound"

        dynamic_variables["sip_from_user"] ||= calling_user.mobile_number
        dynamic_variables["sip_P-Asserted-Identity"] ||= Rack::Utils.escape("+#{calling_user.mobile_number}")

        dynamic_variables["uuid"] ||= incoming_phone_call.sid
        dynamic_variables["RFC2822_DATE"] ||= Rack::Utils.escape(Time.now.rfc2822)
      else
        called_user = user_who_was_called || FactoryGirl.create(:user)
        dynamic_variables["uuid"] ||= FactoryGirl.generate(:guid)
        dynamic_variables["sip_to_user"] ||= called_user.mobile_number
        dynamic_variables["bridge_uuid"] ||= incoming_phone_call.sid
      end

      dynamic_body["variables"].merge!(dynamic_variables)
      dynamic_body.to_xml(:root => "cdr")
    end
  end
end
