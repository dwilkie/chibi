require 'spec_helper'

describe PhoneCall do

  let(:user) { build(:user) }

  let(:new_phone_call) { build(:phone_call, :user => user) }

  let(:welcoming_user_phone_call) { build(:welcoming_user_phone_call, :user => user) }

  phone_call_prompts do |attribute, call_context, reference_phone_call_tag|
    let(reference_phone_call_tag) { build(reference_phone_call_tag) }
  end

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

  describe "#digits" do
    it "should be an accessor but return the set value as an integer" do
      subject.digits = "1234"
      subject.digits.should == 1234
    end
  end

  describe "#process!" do

    shared_examples_for "connecting the user with a friend" do
      it "should connect the user with a friend" do
        reference_phone_call.process!
        reference_phone_call.should be_connecting_user_with_friend
      end
    end

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
        it "should transition to the correct state", :focus do
          phone_call_prompts do |attribute, call_context, reference_phone_call_tag|

            if attribute == :gender
              next_action = :asking_for_looking_for
              in_call_context = call_context
            else
              next_action = :offering_menu
            end

            # Test that transtion is cancelled because of invalid data
            phone_call = send(reference_phone_call_tag)
            phone_call.process!
            phone_call.should send("be_asking_for_#{attribute}#{call_context}")

            # Test that the transition is correct and that the users info is updated
            [:male, :female].each do |sex|
              phone_call = build("#{reference_phone_call_tag}_caller_answers_#{sex}".to_sym)
              asserted_attribute_value = sex.to_s.first
              caller = phone_call.user
              caller_timestamp = caller.updated_at if caller.send(attribute) != asserted_attribute_value
              phone_call.process!
              caller.send(attribute).should == asserted_attribute_value
              caller_timestamp ? caller.updated_at.should > caller_timestamp : caller.should(be_persisted)
              phone_call.should send("be_#{next_action}#{in_call_context}")
            end
          end
        end
      end

      context "offering the menu to the user" do
        context "and the user says they want the menu" do
          it_should_behave_like "asking the user for their gender", :_in_menu do
            let(:reference_phone_call) { build(:offering_menu_phone_call_caller_wants_menu) }
          end
        end

        context "and the user waits for timeout" do
          it_should_behave_like "connecting the user with a friend" do
            let(:reference_phone_call) { build(:offering_menu_phone_call) }
          end
        end
      end
    end
  end

  describe "#to_twiml" do
    include_context "twiml"

    let(:redirect_url) { "http://example.com/twiml" }

    def twiml_response(resource)
      parse_twiml(resource.to_twiml)
    end

    def assert_num_commands(twiml, num_commands)
      twiml.children.size.should == num_commands
    end

    def assert_play_languages(phone_call, filename, options = {})
      assert_play(twiml_response(phone_call), "#{user.locale}/#{filename}", options)

      user = phone_call.user

      original_location = user.location
      user.location = build(:united_states)

      flunk(
        "choose a location with no translation to test the default locale"
      ) if I18n.available_locales.include?(user.locale)

      assert_play(twiml_response(phone_call), "en/#{filename}", options)
      user.location = original_location
    end

    def assert_ask_for_input(prompt, phone_call)
      filename = "ask_for_#{prompt}.mp3"
      assert_play_languages(phone_call, filename)

      phone_call.redirect_url = redirect_url
      twiml = twiml_response(phone_call)

      assert_num_commands(twiml, 2)
      assert_gather(twiml, :numDigits => 1) do |gather|
        assert_play(gather, "#{user.locale}/#{filename}")
      end
      assert_redirect(twiml, redirect_url)
    end

    context "given the redirect url has been set" do
      context "and the phone call is" do

        context "prompting for user input" do
          it "should play the correct prompt" do
            phone_call_prompts do |attribute, call_context, reference_phone_call_tag|
              assert_ask_for_input(attribute, send(reference_phone_call_tag))
            end
          end
        end

        context "welcoming the user" do
          it "should play the welcome message in the user's language" do
            assert_play_languages(welcoming_user_phone_call, "welcome.mp3")
            welcoming_user_phone_call.redirect_url = redirect_url
            twiml = twiml_response(welcoming_user_phone_call)
            assert_num_commands(twiml, 2)
            assert_redirect(twiml, redirect_url)
          end
        end
      end
    end
  end
end
