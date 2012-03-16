require 'spec_helper'

describe "PhoneCalls" do

  describe "POST /phone_calls.xml" do
    include PhoneCallHelpers

    include_context "existing users"
    include_context "twiml"

    let(:my_number) { "8553243313" }
    let(:twiml_response) { parse_twiml(response.body) }

    def current_call(options = {})
      options.is_a?(PhoneCall) ? @call_sid = options.sid : @call_sid ||= make_call(options)
    end

    alias :call :current_call

    def assert_redirect_to_current_url
      assert_redirect(twiml_response, phone_calls_url)
    end

    def assert_ask_for_input(prompt, twiml_options = {})
      twiml_options[:numDigits] ||= 1
      assert_gather(twiml_response, twiml_options) do |gather|
        assert_play(gather, "kh/#{prompt}.mp3")
      end
      assert_redirect_to_current_url
    end

    def update_current_call_status(options = {})
      options[:from] ||= my_number
      options[:call_sid] ||= current_call
      update_call_status(options)
    end

    shared_examples_for "introducing me to chibi" do
      it "should introduce me to Chibi" do
        assert_play(twiml_response, "kh/welcome.mp3")
        assert_redirect_to_current_url
      end
    end

    before do
      load_users
    end

    context "as a user" do
      context "when I call" do
        context "and I am offered the menu" do
          let(:offering_menu_phone_call) { create(:offering_menu_phone_call) }

          before do
            call(offering_menu_phone_call)
          end

          context "if I answer that I want the menu" do
            before do
              update_current_call_status(
                :digits =>  build(:offering_menu_phone_call_caller_wants_menu).digits
              )
            end

            it "should ask me for my age" do
              assert_ask_for_input(:ask_for_age, :numDigits => 2)
            end

            context "and I answer with a valid age" do
              before do
                update_current_call_status(:digits => build(:user_with_age).age)
              end

              it "should ask me if I am male of female" do
                assert_ask_for_input(:ask_for_gender)
              end

              context "and I answer with a valid gender" do
                before do
                  update_current_call_status(
                    :digits => build(:asking_for_gender_in_menu_phone_call_caller_answers_male).digits
                  )
                end

                it "should ask me if I want to chat with a male or female" do
                  assert_ask_for_input(:ask_for_looking_for)
                end

                context "and I answer with a valid looking for preference" do
                  before do
                    update_current_call_status(
                      :digits => build(:asking_for_looking_for_in_menu_phone_call_caller_answers_male).digits
                    )
                  end

                  it "should offer me the menu" do
                    assert_ask_for_input(:offer_menu)
                  end
                end

                context "and I answer with an invalid looking for preference" do
                  before do
                    update_current_call_status(
                      :digits => 3
                    )
                  end

                  it "should ask me again for my looking for preference" do
                    assert_ask_for_input(:ask_for_looking_for)
                  end
                end
              end

              context "and I answer with an invalid gender" do
                before do
                  update_current_call_status(
                    :digits => 3
                  )
                end

                it "should ask me again for my gender" do
                  assert_ask_for_input(:ask_for_gender)
                end
              end
            end

            context "and I answer with an invalid age" do
              before do
                update_current_call_status(:digits => build(:user_who_is_too_young).age)
              end

              it "should ask me again for my age" do
                assert_ask_for_input(:ask_for_age, :numDigits => 2)
              end
            end
          end
        end
      end
    end

    context "as a new user" do
      context "when I call" do
        before do
          call(:from => my_number, :call_sid => build(:phone_call).sid)
        end

        it_should_behave_like "introducing me to chibi"

        context "after I hear the welcome message" do
          before do
            update_current_call_status
          end

          it "should ask me whether I am a guy or a girl" do
            assert_ask_for_input(:ask_for_gender)
          end

          context "if I answer that I am a guy" do
            before do
              update_current_call_status(
                :digits => build(:asking_for_gender_phone_call_caller_answers_male).digits
              )
            end

            it "should ask me whether I want to chat with a guy or a girl" do
              assert_ask_for_input(:ask_for_looking_for)
            end

            context "then if I answer that I want to chat with a girl" do
              before do
                update_current_call_status(
                  :digits =>  build(:asking_for_looking_for_phone_call_caller_answers_female).digits
                )
              end

              it "should offer me the menu" do
                assert_ask_for_input(:offer_menu)
              end

              context "then if I don't want the menu" do
                before do
                  update_current_call_status
                end

                it "should connect me with a girl", :focus do
                  assert_dial(twiml_response, mara.mobile_number)
                end
              end
            end

            context "then if I press '1' for guy" do
              before do
                update_current_call_status(:digits => 1)
              end

              it "should connect me with a guy" do
                pending
              end
            end
          end
        end
      end
    end
  end
end
