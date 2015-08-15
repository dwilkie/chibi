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

  sequence :smsc_token do |n|
    "123abc84-a82e-23a1-b691-b2c19834bce#{n}"
  end

  sequence :twilio_sid do |n|
    "sm908e28e9909641369494f1767ba5c0d#{n}"
  end

  sequence :mobile_number, 855972345678 do |n|
    n.to_s
  end

  sequence :registered_operator_number, 855382345678 do |n|
    n.to_s
  end

  sequence :unregistered_operator_number, 85512239195 do |n|
    n.to_s
  end

  sequence :unknown_operator_number, 61438381912 do |n|
    n.to_s
  end

  sequence :operator_number_with_voice, 85513234567 do |n|
    n.to_s
  end

  sequence :chargeable_operator_number, 85513234567 do |n|
    n.to_s
  end

  sequence :number_without_chibi_smpp_connection, 85513234677 do |n|
    n.to_s
  end

  sequence :landline_number, 855234512345 do |n|
    n.to_s
  end

  factory :msisdn_discovery_run do
    country_code "kh"
    operator "cootel"
    prefix "85538"
    subscriber_number_min 2000000
    subscriber_number_max 9999999

    trait :finished do
      after(:build) do |msisdn_discovery_run|
        msisdn_discovery_run.msisdn_discoveries << build(
          :msisdn_discovery,
          :subscriber_number => msisdn_discovery_run.subscriber_number_max,
          :msisdn_discovery_run => msisdn_discovery_run
        )
      end
    end

    trait :nearly_finished do
      after(:build) do |msisdn_discovery_run|
        msisdn_discovery_run.msisdn_discoveries << build(
          :msisdn_discovery,
          :subscriber_number => msisdn_discovery_run.subscriber_number_max - 1,
          :msisdn_discovery_run => msisdn_discovery_run
        )
      end
    end
  end

  factory :msisdn_discovery do
    msisdn_discovery_run
    sequence(:subscriber_number, 2000000) { |n| n }

    trait :queued_too_long do
      queued_for_discovery
      created_at { 1.day.ago }
    end

    trait :not_started do
    end

    trait :blacklisted do
      association :msisdn_discovery_run, :factory => [:msisdn_discovery_run]
      subscriber_number 2038039
    end

    trait :skipped do
      state "skipped"
    end

    trait :queued_for_discovery do
      state "queued_for_discovery"
    end

    trait :awaiting_result do
      state "awaiting_result"
    end

    trait :active do
      state "active"
    end

    trait :inactive do
      state "inactive"
    end

    trait :with_outdated_state do
      association :reply, :factory => [:reply, :confirmed]
    end
  end

  factory :msisdn do
    mobile_number { generate(:registered_operator_number) }

    trait :from_unregistered_operator do
      mobile_number { generate(:unregistered_operator_number) }
    end

    trait :blacklisted do
      mobile_number "855382038039"
    end

    trait :active do
      active true
    end

    trait :inactive do
      active false
    end
  end

  factory :charge_request do
    association :user, :factory => [:user, :from_chargeable_operator]
    qb

    after(:build) do |charge_request|
      user = charge_request.user
      user.latest_charge_request = charge_request
      user.save!
    end

    trait :awaiting_result do
      state "awaiting_result"
    end

    trait :successful do
      state "successful"
    end

    trait :errored do
      state "errored"
    end

    trait :failed do
      state "failed"
    end

    trait :qb do
      operator "qb"
    end

    trait :from_message do
      association :requester, :factory => :message
    end

    trait :from_phone_call do
      association :requester, :factory => :phone_call
    end

    trait :notify_requester do
      notify_requester true
    end
  end

  factory :message do
    from { generate(:mobile_number) }
    twilio_channel

    transient do
      message_part_body "foo"
    end

    trait :received do
    end

    trait :awaiting_parts do
      multipart
      after(:build) do |message|
        message.number_of_parts += 1
      end
    end

    trait :multipart do
      invalid_multipart

      after(:build) do |message, evaluator|
        message.number_of_parts.times do |index|
          sequence_number = message.number_of_parts - index # create parts out of order
          message.message_parts << build(
            :message_part,
            :message => message,
            :sequence_number => sequence_number,
            :body => evaluator.message_part_body + sequence_number.to_s
          )
        end
      end
    end

    trait :single_part do
      multipart
      number_of_parts 1
      csms_reference_number 0
    end

    trait :invalid_multipart do
      invalid_multipart_csms_reference_number
      invalid_multipart_number_of_parts
    end

    trait :invalid_multipart_csms_reference_number do
      csms_reference_number 1
    end

    trait :invalid_multipart_number_of_parts do
      number_of_parts 2
    end

    trait :twilio_channel do
      channel "twilio"
    end

    trait :with_guid do
      guid
    end

    trait :processed do
      state "processed"
    end

    trait :awaiting_charge_result do
      state "awaiting_charge_result"
    end

    trait :unprocessed do
      received
      created_at { 5.minutes.ago }
    end

    trait :without_user do
      user nil
      from { generate(:mobile_number) }
    end
  end

  factory :message_part do
    sequence_number 1
    body "foo"
    message
  end

  factory :phone_call do
    from { generate(:mobile_number) }
    sid { generate(:guid) }

    trait :answered do
      state "answered"
    end

    trait :transitioning_from_answered do
      state "transitioning_from_answered"
    end

    trait :telling_user_they_dont_have_enough_credit do
      state "telling_user_they_dont_have_enough_credit"
    end

    trait :transitioning_from_telling_user_they_dont_have_enough_credit do
      state "transitioning_from_telling_user_they_dont_have_enough_credit"
    end

    trait :awaiting_completion do
      state "awaiting_completion"
    end

    trait :completed do
      state "completed"
    end

    trait :connecting_user_with_friend do
      state "connecting_user_with_friend"
    end

    trait  :transitioning_from_connecting_user_with_friend do
      state "transitioning_from_connecting_user_with_friend"
    end

    trait :finding_friends do
      state "finding_friends"
    end

    trait :transitioning_from_finding_friends do
      state "transitioning_from_finding_friends"
    end

    trait :dialing_friends do
      state "dialing_friends"
    end

    trait :transitioning_from_dialing_friends do
      state "transitioning_from_dialing_friends"
    end

    trait :found_friends do
      after(:create) do |phone_call|
        create_list(
          :chat, 5, :friend_active, :user => phone_call.user, :starter => phone_call
        )
      end
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
    for_user
    body "body"

    trait :for_user do
      user
    end

    trait :undelivered do
      delivered_at nil
    end

    trait :delivered do
      delivered_at { Time.current }
    end

    trait :pending_delivery do
    end

    trait :queued_for_smsc_delivery do
      delivered
      state "queued_for_smsc_delivery"
    end

    trait :accepted_by_smsc do
      with_token
      delivered
    end

    trait :delivered_by_smsc do
      state "delivered_by_smsc"
      accepted_by_smsc
    end

    trait :failed do
      state "failed"
      accepted_by_smsc
    end

    trait :confirmed do
      state "confirmed"
      accepted_by_smsc
    end

    trait :expired do
      state "expired"
      accepted_by_smsc
    end

    trait :errored do
      state "errored"
      accepted_by_smsc
    end

    trait :unknown do
      state "unknown"
      accepted_by_smsc
    end

    trait :with_token do
      token { generate(:smsc_token) }
    end

    trait :twilio_channel do
      delivery_channel "twilio"
    end

    trait :twilio_delivered_by_smsc do
      state "delivered_by_smsc"
      delivered
      with_twilio_token
    end

    trait :with_twilio_token do
      token { generate(:twilio_sid) }
    end

    trait :smsc_channel do
      delivery_channel "smsc"
    end

    trait :with_no_body do
      body nil
    end

    trait :for_msisdn_discovery do
      user nil
      msisdn_discovery
      to { msisdn_discovery.mobile_number }
    end

    trait :foo_bar do
      queued_for_smsc_delivery
      delivered_at { 1.day.ago }
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
      end
    end

    trait :friend_active do
      after(:create) do |chat|
        chat.active_users << chat.friend
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

    trait :will_permanently_timeout do
      updated_at { 24.hours.ago }
    end

    trait :will_provisionally_timeout do
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
      latitude 40.7127837
      longitude -74.0059413
    end
  end

  factory :user do
    cambodian

    trait :cannot_receive_sms do
      with_landline_number
    end

    trait :with_recent_interaction do
      last_interacted_at { Time.current }
    end

    trait :with_semi_recent_interaction do
      last_interacted_at { 15.minutes.ago }
    end

    trait :never_contacted do
      updated_at { 10.days.ago }
    end

    trait :without_recent_interaction do
      last_interacted_at { 1.month.ago }
    end

    trait :not_contacted_recently do
      last_contacted_at { 6.days.ago }
    end

    trait :not_contacted_for_a_long_time do
      last_contacted_at { 8.days.ago }
    end

    trait :not_contacted_for_a_short_time do
      updated_at { 4.days.ago }
    end

    trait :from_registered_service_provider do
      mobile_number { generate(:registered_operator_number) }
    end

    trait :from_operator_with_voice do
      mobile_number { generate(:operator_number_with_voice) }
    end

    trait :from_chargeable_operator do
      mobile_number { generate(:chargeable_operator_number) }
    end

    trait :from_unknown_operator do
      mobile_number { generate(:unknown_operator_number) }
    end

    trait :from_operator_without_chibi_smpp_connection do
      mobile_number { generate(:number_without_chibi_smpp_connection) }
    end

    trait :with_landline_number do
      mobile_number { generate(:landline_number) }
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

    trait :gay do
      male
      looking_for "m"
    end

    trait :lesbian do
      female
      looking_for "f"
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
      mobile_number
    end

    trait :from_kampong_thom do
      sequence(:mobile_number, 85562234567) { |n| n.to_s }
    end

    trait :from_phnom_penh do
      sequence(:mobile_number, 85523234567) { |n| n.to_s }
    end

    trait :from_battambang do
      sequence(:mobile_number, 85553234567) { |n| n.to_s }
    end

    trait :from_siem_reap do
      sequence(:mobile_number, 85563234567) { |n| n.to_s }
    end

    trait :english do
      sequence(:mobile_number, 447624234567) { |n| n.to_s }
    end

    trait :filipino do
      sequence(:mobile_number, 639192636682) { |n| n.to_s }
    end

    trait :american do
      sequence(:mobile_number, 14162345678) { |n| n.to_s }
    end

    trait :thai do
      sequence(:mobile_number, 66814234567) { |n| n.to_s }
    end

    # do not reorder these factories because the tests rely on
    # the order so they fail when match statements are left off

    # users with unknown details
    factory :alex do
      name "alex"
      with_recent_interaction
    end

    factory :jamie do
      name "jamie"
      with_semi_recent_interaction
    end

    # user with unknown gender
    factory :chamroune do
      name "chamroune"
      with_recent_interaction
    end

    # never interacted, with unknown gender
    factory :reaksmey do
      name "reaksmey"
    end

    # user with unknown looking for preference
    factory :pauline do
      name "pauline"
      gender "f"
      with_recent_interaction
      from_registered_service_provider
    end

    # user with known age but unknown gender
    factory :kris do
      name "kris"
      age 25
      with_semi_recent_interaction
    end

    # girls
    factory :nok do
      name "nok"
      gender "f"
      with_semi_recent_interaction
      thai
      association :location, :chiang_mai

      factory :joy do
        name "joy"
        age 27
        cambodian
        association :location, :phnom_penh
      end
    end

    # guys
    factory :paul do
      name "paul"
      age 39
      gender "m"
      with_semi_recent_interaction
      association :location, :phnom_penh

      factory :con do
        name "con"
        age 37
        association :location, :siem_reap
      end

      factory :dave do
        name "dave"
        age 28
        with_recent_interaction
      end

      factory :luke do
        name "luke"
        age 25
        with_recent_interaction
      end
    end

    # lesbians
    factory :harriet do
      name "harriet"
      gender "f"
      looking_for "f"
      with_semi_recent_interaction
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
      with_semi_recent_interaction
      thai
      association :location, :chiang_mai

      factory :view do
        name "view"
        age 26
      end
    end

    factory :mara do
      name "mara"
      gender "f"
      age 25
      with_semi_recent_interaction
      association :location, :phnom_penh
    end

    factory :michael do
      name "michael"
      gender "m"
      age 29
      with_semi_recent_interaction
      thai
      association :location, :chiang_mai
    end
  end

  factory :call_data_record do
    transient do
      cdr_variables nil
      user nil
      user_who_called nil
      user_who_was_called nil
      phone_call nil

      default_body <<-CDR
        <?xml version="1.0"?>
        <cdr core-uuid="fa2fc41d-ccc1-478b-99b8-4b90e74bb11d">
        </cdr>
      CDR
    end

    body do
      dynamic_body = MultiXml.parse(default_body)["cdr"]
      calling_user = user_who_called || user || FactoryGirl.create(:user)

      dynamic_cdr = cdr_variables || {}
      dynamic_cdr_variables = dynamic_cdr["variables"] ||= {}

      dynamic_cdr_callflow = dynamic_cdr["callflow"] ||= {}
      dynamic_cdr_callflow_caller_profile = dynamic_cdr_callflow["caller_profile"] ||= {}

      dynamic_cdr_variables["direction"] ||= "inbound"
      dynamic_cdr_variables["duration"] ||= "20"
      dynamic_cdr_variables["billsec"] ||= "15"

      if dynamic_cdr_variables["direction"] == "inbound"
        dynamic_cdr_variables["sip_from_user"] ||= calling_user.mobile_number
        dynamic_cdr_variables["sip_from_user_stripped"] ||= dynamic_cdr_variables["sip_from_user"]
        dynamic_cdr_variables["sip_P-Asserted-Identity"] ||= Rack::Utils.escape("+#{dynamic_cdr_variables["sip_from_user"]}")

        dynamic_cdr_variables["uuid"] ||= phone_call.try(:sid) || FactoryGirl.generate(:guid)
        dynamic_cdr_variables["start_epoch"] ||= Time.current.to_i.to_s
      else
        called_user = user_who_was_called || FactoryGirl.create(:user)
        default_host = "27.109.112.12"
        dynamic_cdr_variables["uuid"] ||= FactoryGirl.generate(:guid)
        dynamic_cdr_variables["sip_to_user"] ||= called_user.mobile_number
        dynamic_cdr_variables["sip_to_host"] ||= default_host
        dynamic_cdr_callflow_caller_profile["destination_number"] ||= called_user.mobile_number
        dynamic_cdr_callflow_caller_profile["network_addr"] ||= default_host
      end

      dynamic_body.deep_merge!(dynamic_cdr)
      dynamic_body.to_xml(:root => "cdr")
    end
  end
end
