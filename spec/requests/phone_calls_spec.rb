require 'spec_helper'

describe "PhoneCalls" do
  describe "POST /phone_calls.xml" do
    include PhoneCallHelpers
    include PhoneCallHelpers::Twilio
    include MobilePhoneHelpers

    include_context "existing users"
    include_context "twiml"

    let(:twiml_response) { parse_twiml(response.body) }
    let(:my_number) { "855977123876" }
    let(:new_user) { User.where(:mobile_number => my_number).first }

    def current_call(options = {})
      options.is_a?(PhoneCall) ? @call_sid = options.sid : @call_sid ||= make_call(options)
    end

    alias :call :current_call

    def phone_call_callback_url
      phone_calls_url(:format => :xml)
    end

    def assert_redirect_to_current_url
      assert_redirect(twiml_response, phone_call_callback_url)
    end

    def assert_play_then_redirect_to_current_url(file)
      assert_play(twiml_response, "kh/#{filename_with_extension(file)}")
      assert_redirect_to_current_url
    end

    def assert_dial_to_current_url(number, options = {})
      assert_dial(twiml_response, phone_call_callback_url, number, options)
    end

    def assert_ask_for_input(prompt, twiml_options = {})
      twiml_options[:numDigits] ||= 1
      assert_gather(twiml_response, twiml_options) do |gather|
        assert_play(gather, "kh/#{filename_with_extension(prompt)}")
      end
      assert_redirect_to_current_url
    end

    def update_current_call_status(options = {})
      options[:call_sid] ||= current_call
      update_call_status(options)
    end

    shared_examples_for "a phone call without voice prompts" do
      context "given that I'm already in a chat session" do
        let!(:active_chat) { create(:chat, :active) }

        context "when I call" do
          before do
            call(:from => active_chat.user)
          end

          it "should connect me with my friend" do
            assert_dial_to_current_url(active_chat.friend.mobile_number)
          end
        end
      end

      context "given there are new friends online" do
        let(:friends) { caller.matches.all }
        let(:caller) { User.first }

        before do
          load_users
          caller
          friends
        end

        context "when I call" do
          before do
            call(:from => caller.mobile_number)
          end

          it "should try to find me a new friend" do
            assert_redirect_to_current_url
          end

          context "after a girl is found for me" do
            context "given I'm calling to Twilio" do
              before do
                update_current_call_status
              end

              it "should try to connect me with her through Twilio" do
                assert_dial_to_current_url(friends[0].mobile_number)
              end

              context "if she answers" do
                context "and hangs up first" do
                  before do
                    update_current_call_status(:dial_call_status => :completed)
                  end

                  context "if I hold the line" do
                    before do
                      update_current_call_status
                    end

                    it "should connect me with a new friend" do
                      assert_dial_to_current_url(friends[1].mobile_number)
                    end
                  end
                end
              end
            end

            context "given I'm calling to 2442" do
              before do
                update_current_call_status(:api_version => sample_adhearsion_twilio_api_version)
              end

              it "should try to connect me with her through the default PBX dial string" do
                assert_dial_to_current_url(
                  asserted_default_pbx_dial_string(:number_to_dial => friends[0].mobile_number)
                )
              end
            end
          end
        end
      end
    end

    shared_examples_for "a phone call with voice prompts" do
      context "when I call" do
        before do
          call(:from => my_number)
        end

        it "should introduce me to Chibi" do
          assert_play_then_redirect_to_current_url(:welcome)
        end

        context "after I hear the welcome message" do
          before do
            update_current_call_status
          end

          it "should offer me the menu" do
            assert_ask_for_input(:offer_menu)
          end

          context "if I answer that I want the menu" do
            before do
              update_current_call_status(
                :digits =>  build(:phone_call, :offering_menu, :caller_wants_menu).digits
              )
            end

            it "should ask me for my age" do
              assert_ask_for_input(:ask_for_age, :numDigits => 2)
            end

            context "and I answer with a valid age" do
              before do
                update_current_call_status(:digits => build(:user, :with_date_of_birth).age)
              end

              it "should save my preference and ask me if I am male of female" do
                assert_ask_for_input(:ask_for_gender)
              end

              context "and I answer with a valid gender" do
                before do
                  update_current_call_status(
                    :digits => build(
                      :phone_call, :asking_for_gender_in_menu, :caller_answers_male
                    ).digits
                  )
                end

                it "should ask me if I want to chat with a boy or a girl" do
                  assert_ask_for_input(:ask_for_looking_for)
                end

                context "and I answer with a valid looking for preference" do
                  before do
                    update_current_call_status(
                      :digits => build(
                        :phone_call, :asking_for_looking_for_in_menu, :caller_answers_male
                      ).digits
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

                  it "should ignore my input and offer me the menu" do
                    assert_ask_for_input(:offer_menu)
                  end
                end
              end

              context "and I answer with an invalid gender" do
                before do
                  update_current_call_status(
                    :digits => 3
                  )
                end

                it "should ignore my input and ask me if I want to chat with a boy or a girl" do
                  assert_ask_for_input(:ask_for_looking_for)
                end
              end
            end

            context "and I answer with an invalid age" do
              before do
                update_current_call_status(:digits => build(:user, :too_young).age)
              end

              it "should ignore my input and ask me for my gender" do
                assert_ask_for_input(:ask_for_gender)
              end
            end
          end

          context "given that I'm already in a chat session" do
            let!(:active_chat) { create(:chat, :active, :user => new_user) }

            context "if I hold the line" do
              before do
                update_current_call_status
              end

              it "should connect me with my friend" do
                assert_dial_to_current_url(active_chat.friend.mobile_number)
              end
            end
          end

          context "given there are no new friends online" do
            context "and I hold the line" do
              before do
                update_current_call_status
              end

              it "should try to find me a friend" do
                assert_redirect_to_current_url
              end

              context "after no matches are found" do
                before do
                  update_current_call_status
                end

                it "should tell me to try again later" do
                  assert_play_then_redirect_to_current_url(:tell_user_to_try_again_later)
                end

                context "if I keep holding the line" do
                  before do
                    update_current_call_status
                  end

                  it "should hang up" do
                    assert_hangup(twiml_response)
                  end
                end
              end
            end
          end

          context "given there are new friends online" do
            let(:friends) { new_user.matches.all }

            before do
              load_users
              friends
            end

            context "and I hold the line" do
              before do
                update_current_call_status
              end

              it "should try to find me a new friend" do
                assert_redirect_to_current_url
              end

              context "after a girl is found for me" do
                context "given I'm calling to Twilio" do
                  before do
                    update_current_call_status
                  end

                  it "should try to connect me with her through Twilio" do
                    assert_dial_to_current_url(friends[0].mobile_number)
                  end

                  context "if she answers" do
                    context "and hangs up first" do
                      before do
                        update_current_call_status(:dial_call_status => :completed)
                      end

                      it "should tell me that my chat has ended" do
                        assert_play_then_redirect_to_current_url(:tell_user_their_chat_has_ended)
                      end

                      context "and I hold the line" do
                        before do
                          update_current_call_status
                        end

                        it "should offer me the menu" do
                          assert_ask_for_input(:offer_menu)
                        end
                      end
                    end
                  end

                  context "but she does not answer" do
                    before do
                      update_current_call_status(:dial_call_status => :no_answer)
                    end

                    it "should find me a new friend" do
                      assert_redirect_to_current_url
                    end

                    context "and I hold the line" do
                      before do
                        update_current_call_status
                      end

                      it "should connnect me with my new friend" do
                        assert_dial_to_current_url(friends[1].mobile_number)
                      end
                    end
                  end
                end

                context "given I'm calling to 2442" do
                  before do
                    update_current_call_status(:api_version => sample_adhearsion_twilio_api_version)
                  end

                  it "should try and connect me with her through the default PBX dial string" do
                    assert_dial_to_current_url(
                      asserted_default_pbx_dial_string(:number_to_dial => friends[0].mobile_number)
                    )
                  end
                end
              end
            end
          end
        end
      end
    end

    shared_examples_for "saving the phone call" do
      it "should save the phone call" do
        new_phone_call = PhoneCall.last
        new_phone_call.from.should == from
      end
    end

    shared_examples_for "a call from an offline user" do
      context "given I am offline" do
        let(:offline_user) { create(:user, :offline) }

        before do
          call(:from => offline_user)
        end

        it "should put me online" do
          offline_user.reload.should be_online
        end
      end
    end

    context "when I call" do
      it_should_behave_like "a call from an offline user"

      context "to Twilio" do
        before do
          call(:from => my_number)
        end

        it_should_behave_like "saving the phone call" do
          let(:from) { my_number }
        end
      end
    end

    it_should_behave_like "a phone call without voice prompts"

    context "when I call to the short code '2442'" do
      before do
        call(:from => "+85510236139", :to => "+2442", :api_version => "adhearsion-twilio-0.0.1")
      end

      it_should_behave_like "saving the phone call" do
        let(:from) { "85510236139" }
      end
    end

    context "when I call to a number from the Twilio number" do
      before do
        call(:from => twilio_number, :to => "+85510236139")
      end

      it_should_behave_like "saving the phone call" do
        let(:from) { "85510236139" }
      end
    end

    context "when I am called" do
      context "and I answer" do
        before do
          call(:to => my_number)
        end

        it_should_behave_like "saving the phone call" do
          let(:from) { my_number }
        end
      end
    end
  end
end
