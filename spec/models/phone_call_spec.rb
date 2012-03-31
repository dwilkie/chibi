require 'spec_helper'

include PhoneCallHelpers::States

describe PhoneCall do
  let(:phone_call) { create(:phone_call) }
  let(:new_phone_call) { build(:phone_call) }

  describe "factory" do
    it "should be valid" do
      new_phone_call.should be_valid
    end
  end

  it "should not be valid without an sid" do
    new_phone_call.sid = nil
    new_phone_call.should_not be_valid
  end

  it "should not be valid with a duplicate sid" do
    new_phone_call.sid = phone_call.sid
    new_phone_call.should_not be_valid
  end

  it_should_behave_like "communicable" do
    let(:communicable_resource) { new_phone_call }
  end

  it_should_behave_like "chatable" do
    let(:chatable_resource) { new_phone_call }
  end

  describe "#call_sid" do
    it "should be an alias for the attribute '#sid'" do
      subject.sid = 123
      subject.call_sid.should == 123

      subject.call_sid = 456
      subject.sid.should == 456
    end
  end

  describe "#redirect_url" do
    it "should be an accessor" do
      subject.redirect_url = "some_url"
      subject.redirect_url.should == "some_url"
    end
  end

  describe "#dial_status" do
    it "should be an accessor" do
      subject.dial_status = "some_status"
      subject.dial_status.should == "some_status"
    end
  end

  describe "#call_status" do
    it "should be an accessor" do
      subject.call_status = "some_call_status"
      subject.call_status.should == "some_call_status"
    end
  end

  describe "#to" do
    # phone calls should behave the same whether they were initiated by
    # the user or not
    it "should be an accessor that overrides #from if present" do
      subject.from = "+1-2345-2222"
      subject.to = "+1-2345-3333"
      subject.from.should == "123453333"

      subject.to = ""
      subject.from.should == "123453333"
    end

    it "should be mass assignable" do
      new_phone_call = subject.class.new(:from => "+1-2345-2222", :to => "+1-2345-3333")
      new_phone_call.from.should == "123453333"
    end
  end

  describe "#digits" do
    it "should be an accessor but return the set value as an integer" do
      subject.digits = "1234"
      subject.digits.should == 1234
    end
  end

  describe "#process!" do
    def assert_phone_call_can_be_completed(reference_phone_call)
      reference_phone_call.call_status = "completed"
      reference_phone_call.process!
      reference_phone_call.should be_completed
    end

    def assert_phone_call_attributes(resource, expectations)
      expectations.each do |attribute, value|
        if value.is_a?(Hash)
          assert_phone_call_attributes(resource.send(attribute), value)
        else
          resource.send(attribute).should == value
        end
      end
    end

    it "should transition to the correct state", :focus do
      with_phone_call_states do |factory_name, phone_call_state, next_state, sub_factories|
        assert_phone_call_can_be_completed(build(factory_name))

        phone_call = build(factory_name)
        phone_call.process!
        phone_call.should send("be_#{next_state}")

        sub_factories.each do |sub_factory_name, sub_factory_attributes|
          next_sub_factory_state = sub_factory_attributes.keys.first
          expectations = sub_factory_attributes.values.first["expectations"] || {}

          phone_call = build(sub_factory_name)
          phone_call.process!
          phone_call.should send("be_#{next_sub_factory_state}")

          assert_phone_call_attributes(phone_call, expectations)
        end
      end
    end
  end

  describe "#to_twiml" do
    include_context "twiml"

    let(:redirect_url) { authenticated_url("http://example.com/twiml") }

    def twiml_response(resource)
      resource.redirect_url = redirect_url
      parse_twiml(resource.to_twiml)
    end

    def assert_dial_to_redirect_url(twiml, number, options = {})
      assert_dial(twiml, redirect_url, number, options)
    end

    def assert_play_languages(phone_call, filename, options = {})
      user = phone_call.user
      filename_with_extension = filename_with_extension(filename)

      twiml = twiml_response(phone_call)

      assert_play(twiml, "#{user.locale}/#{filename_with_extension}", options)
      assert_redirect(twiml, redirect_url, options)

      original_location = user.location
      user.location = build(:united_states)

      flunk(
        "choose a location with no translation to test the default locale"
      ) if I18n.available_locales.include?(user.locale)

      assert_play(twiml_response(phone_call), "en/#{filename_with_extension}", options)
      user.location = original_location
    end

    def assert_ask_for_input(prompt, phone_call, twiml_options = {})
      # automatically asserts redirect
      assert_play_languages(phone_call, prompt)
      filename_with_extension = filename_with_extension(prompt)

      twiml_options[:numDigits] ||= 1
      assert_gather(twiml_response(phone_call), twiml_options) do |gather|
        assert_play(gather, "#{phone_call.user.locale}/#{filename_with_extension}")
      end
    end

    context "given the redirect url has been set" do
      context "and the phone call is" do

        context "welcoming the user" do
          it "should play the welcome message in the user's language" do
            assert_play_languages(welcoming_user_phone_call, :welcome)
          end
        end

        context "prompting for user input" do
          it "should play the correct prompt" do
            with_phone_call_prompts do |attribute, call_context, reference_phone_call_tag, prompt_state, next_state, twiml_options|
              twiml_options ||= {}
              assert_ask_for_input("ask_for_#{attribute}", send(reference_phone_call_tag), twiml_options)
            end
          end
        end

        context "offering the menu" do
          it "should offer the menu" do
            assert_ask_for_input(:offer_menu, offering_menu_phone_call)
          end
        end

        context "asking if the user wants to find a new friend or call their existing one" do
          it "should ask the user if they want to find a new friend or call their existing chat partner" do
            assert_ask_for_input(
              :ask_if_they_want_to_find_a_new_friend_or_call_existing_chat_partner,
              build(:asking_if_user_wants_to_find_a_new_friend_or_call_existing_one_phone_call)
            )
          end
        end

        context "telling the user to try again later" do
          it "should tell the user to try again later" do
            assert_play_languages(
              send(:telling_user_to_try_again_later_phone_call),
              :tell_user_to_try_again_later
            )
          end
        end

        context "finding a new friend" do
          it "should redirect" do
            assert_redirect(twiml_response(finding_new_friend_phone_call), redirect_url)
          end
        end

        context "hanging up" do
          it "should hang up" do
            assert_hangup(twiml_response(build(:hanging_up_phone_call)))
          end
        end

        context "completed" do
          it "should return nothing" do
            build(:completed_phone_call).to_twiml.should be_nil
          end
        end

        context "telling the user that their friend is unavailable to chat" do
          it "should tell the user that their friend is unavailable to chat" do
            assert_play_languages(
              build(:telling_user_their_friend_is_unavailable_phone_call),
              :tell_user_their_friend_is_unavailable
            )
          end
        end

        context "connecting the user" do
          include PhoneCallHelpers::Twilio

          include_context "existing users"

          context "with a new friend" do
            before do
              load_users # without short codes
            end

            context "who has a short code" do
              before do
                users_from_registered_service_providers
              end

              it "should dial a new friend and set the callerId to the new friends mobile operator short code" do
                user = users_from_registered_service_providers.first
                users_new_friend = user.match
                twiml = twiml_response(build(:connecting_user_with_new_friend_phone_call, :user => user))
                assert_dial_to_redirect_url(
                  twiml, users_new_friend.mobile_number, :callerId => users_new_friend.short_code
                )
              end
            end

            context "who does not have a short code" do
              it "should dial a new friend and set the callerId to the Twilio number" do
                twiml = twiml_response(build(:connecting_user_with_new_friend_phone_call, :user => dave))
                assert_dial_to_redirect_url(
                  twiml,
                  dave.match.mobile_number,
                  :callerId => formatted_twilio_number
                )
              end
            end
          end

          context "with his existing friend" do

            context "who has a short code" do
              # scenario: John started a chat with Jane and is actively chatting
              # Jane calls in so Jane is the dialer and John is the dialers friend
              # John belongs to a mobile operator with a registered short code
              let(:dialer) { users_from_registered_service_providers.first }
              let(:dialers_friend) { users_from_registered_service_providers.last }
              let(:active_chat) { create(:active_chat, :user => dialers_friend, :friend => dialer) }

              before do
                active_chat
              end

              it "should dial the friend and set the callerId to the friends mobile operator short code" do
                twiml = twiml_response(
                  build(:connecting_user_with_existing_friend_phone_call, :user => dialer, :chat => active_chat)
                )

                assert_dial_to_redirect_url(
                  twiml, dialers_friend.mobile_number, :callerId => dialers_friend.short_code
                )
              end
            end

            context "who does not have a short code" do
              # scenario: Andy started a chat with Kunthia and is actively chatting
              # Andy calls in so Andy is the dialer and Kunthia is the dialers friend
              # Kunthia does not belong to a mobile operator with a registered short code

              let(:active_chat) { create(:active_chat) }

              let(:dialer) { active_chat.user }
              let(:dialers_friend) { active_chat.friend }

              before do
                active_chat
              end

              it "should dial the friend and set the callerId to Twilio number" do
                twiml = twiml_response(
                  build(:connecting_user_with_existing_friend_phone_call, :user => dialer, :chat => active_chat)
                )

                assert_dial_to_redirect_url(
                  twiml, dialers_friend.mobile_number, :callerId => formatted_twilio_number
                )
              end
            end
          end
        end
      end
    end
  end
end
