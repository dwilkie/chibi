require 'spec_helper'

include PhoneCallHelpers::PromptStates

describe PhoneCall do
  let(:phone_call) { create(:phone_call) }
  let(:new_phone_call) { build(:phone_call) }
  let(:welcoming_user_phone_call) { build(:welcoming_user_phone_call) }

  with_phone_call_prompts do |attribute, call_context, reference_phone_call_tag|
    let(reference_phone_call_tag) { build(reference_phone_call_tag) }
  end

  let(:offering_menu_phone_call) { build(:offering_menu_phone_call) }

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

    shared_examples_for "asking the user for their gender" do |call_context|
      it "should ask the user for their gender" do
        reference_phone_call.process!
        reference_phone_call.should send("be_asking_for_gender#{call_context}")
      end
    end

    shared_examples_for "asking the user for their looking for preference" do |call_context|
      it "should ask the user for their looking for preference" do
        reference_phone_call.process!
        reference_phone_call.should send("be_asking_for_looking_for#{call_context}")
      end
    end

    shared_examples_for "offering the user the menu" do
      it "should offer the user the menu" do
        reference_phone_call.process!
        reference_phone_call.should be_offering_menu
      end
    end

    shared_examples_for "connecting the user with a new friend" do
      it "should connect the user with a new friend" do
        reference_phone_call.process!
        reference_phone_call.should be_connecting_user_with_new_friend
      end
    end

    context "the phone call is" do
      context "answered" do
        it "should welcome the user" do
          new_phone_call.process!
          new_phone_call.should be_welcoming_user
        end
      end

      context "welcoming the user" do
        context "and the users gender is unknown" do
          it_should_behave_like "asking the user for their gender" do
            let(:reference_phone_call) { welcoming_user_phone_call }
          end
        end

        context "and the users gender is already known" do
          context "given the user's looking for preference is" do
            context "unknown" do
              it_should_behave_like "asking the user for their looking for preference" do
                let(:reference_phone_call) do
                  build(:welcoming_user_phone_call_from_user_with_known_gender)
                end
              end
            end

            context "already known" do
              it_should_behave_like "offering the user the menu" do
                let(:reference_phone_call) do
                  build(:welcoming_user_phone_call_from_user_with_known_gender_and_looking_for_preference)
                end
              end
            end
          end
        end
      end

      context "prompting for user input" do
        include PhoneCallHelpers::PromptStates::GenderAnswers

        def assert_attribute_updated_and_transition(phone_call, attribute, asserted_attribute_value, next_state)
          caller = phone_call.user
          caller_timestamp = caller.updated_at if caller.send(attribute) != asserted_attribute_value
          phone_call.process!
          caller.send(attribute).should == asserted_attribute_value
          caller_timestamp ? caller.updated_at.should > caller_timestamp : caller.should(be_persisted)
          phone_call.should send("be_#{next_state}")
        end

        it "should transition to the correct state" do
          with_phone_call_prompts do |attribute, call_context, reference_phone_call_tag, prompt_state, next_state|
            # Test that transtion is cancelled because of an invalid selection
            phone_call = send(reference_phone_call_tag)
            phone_call.process!
            phone_call.should send("be_#{prompt_state}")

            # Test that the transition is correct and that the users info is updated
            with_gender_answers(reference_phone_call_tag, attribute) do |sex, reference_phone_call_tag_with_gender|
              assert_attribute_updated_and_transition(
                build(reference_phone_call_tag_with_gender), attribute, sex.to_s.first, next_state
              )
            end

            # Test age input
            if attribute == :age
              phone_call.digits = "24"
              assert_attribute_updated_and_transition(phone_call, attribute, 24, next_state)
            end
          end
        end
      end

      context "offering the menu to the user" do
        context "and the user says they want the menu" do
          it "should ask the user for their age" do
            phone_call = build(:offering_menu_phone_call_caller_wants_menu)
            phone_call.process!
            phone_call.should be_asking_for_age_in_menu
          end
        end

        context "and the user holds the line" do
          context "and they are already in a chat session with a friend" do
            before do
              create(:active_chat, :user => offering_menu_phone_call.user)
            end

            it "should ask them if they want to call their friend (again) or find a new one" do
              offering_menu_phone_call.process!
              offering_menu_phone_call.should be_asking_if_user_wants_to_find_a_new_friend_or_call_existing_one
            end
          end

          context "and they are not currently in a chat session with a friend" do
            context "but there are no other users online to chat with" do
              it "should tell the user to try again later" do
                offering_menu_phone_call.process!
                offering_menu_phone_call.should be_telling_user_to_try_again_later
              end
            end

            context "and there are other users online available to chat" do
              before do
                offering_menu_phone_call.user.stub(:matches).and_return([build(:user)])
              end

              it_should_behave_like "connecting the user with a new friend" do
                let(:reference_phone_call) { offering_menu_phone_call }
              end
            end
          end
        end
      end

      context "asking_if_user_wants_to_find_a_new_friend_or_call_existing_one" do
        factory_name = :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one_phone_call

        shared_examples_for "connecting the user with his existing friend" do
          it "should connect the user with his existing friend" do
            reference_phone_call.process!
            reference_phone_call.should be_connecting_user_with_existing_friend
          end
        end

        context "and the user wants to call his existing friend" do
          it_should_behave_like "connecting the user with his existing friend" do
            let(:reference_phone_call) {
              build("#{factory_name}_caller_wants_existing_friend".to_sym)
            }
          end
        end

        context "and the user wants to meet a new friend" do
          it_should_behave_like "connecting the user with a new friend" do
            let(:reference_phone_call) {
              build("#{factory_name}_caller_wants_new_friend".to_sym)
            }
          end
        end

        context "and the user makes no choice" do
          it_should_behave_like "connecting the user with his existing friend" do
            let(:reference_phone_call) { build(factory_name) }
          end
        end
      end
    end
  end

  describe "#to_twiml" do
    include_context "twiml"

    let(:redirect_url) { authenticated_url("http://example.com/twiml") }

    def twiml_response(resource)
      parse_twiml(resource.to_twiml)
    end

    def assert_play_languages(phone_call, filename, options = {})
      user = phone_call.user
      filename_with_extension = filename_with_extension(filename)

      options[:redirect_url] ||= redirect_url unless options[:hangup]
      phone_call.redirect_url = options[:redirect_url]

      assert_play(twiml_response(phone_call), "#{user.locale}/#{filename_with_extension}", options)

      original_location = user.location
      user.location = build(:united_states)

      flunk(
        "choose a location with no translation to test the default locale"
      ) if I18n.available_locales.include?(user.locale)

      assert_play(twiml_response(phone_call), "en/#{filename_with_extension}", options)
      user.location = original_location
    end

    def assert_ask_for_input(prompt, phone_call, twiml_options = {})
      # automatically asserts redirect when calling with no options
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

        context "asking_if_user_wants_to_find_a_new_friend_or_call_existing_one" do
          it "should ask the user if they want to find a new friend or call their existing chat partner" do
            assert_ask_for_input(
              :ask_if_they_want_to_find_a_new_friend_or_call_existing_chat_partner,
              build(:asking_if_user_wants_to_find_a_new_friend_or_call_existing_one_phone_call)
            )
          end
        end

        context "telling_user_to_try_again_later" do
          it "should tell the user to try again later and hangup the call" do
            assert_play_languages(
              build(:telling_user_to_try_again_later_phone_call),
              :tell_user_to_try_again_later,
              :hangup => true
            )
          end
        end

        context "connecting user with a new friend" do
          include_context "existing users"

          before do
            load_users
          end

          context "the matched user has a short code" do
            before do
              users_from_registered_service_providers
            end

            it "should dial a new friend and set the callerId to the new friends mobile operator short code" do
              user = users_from_registered_service_providers.first
              users_new_friend = user.match
              twiml = twiml_response(build(:connecting_user_with_new_friend_phone_call, :user => user))
              assert_dial(twiml, users_new_friend.mobile_number, :callerId => users_new_friend.short_code)
            end
          end

          context "the matched user does not have a short code" do
            it "should dial a new friend and set the callerId to the Twilio number" do
              twiml = twiml_response(build(:connecting_user_with_new_friend_phone_call, :user => dave))
              assert_dial(
                twiml,
                dave.match.mobile_number,
                :callerId => Phony.formatted(
                  ENV['TWILIO_OUTGOING_NUMBER'], :format => :international, :spaces => ""
                )
              )
            end
          end
        end
      end
    end
  end
end
