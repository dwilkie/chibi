# encoding: utf-8

require 'spec_helper'

describe "Messages" do

  describe "POST /messages" do
    include MessagingHelpers
    include TranslationHelpers

    include_context "existing users"
    include_context "replies"

    let(:new_user) { User.last }
    let(:new_location) { Location.last }
    let(:new_message) { Message.last }

    let(:my_number) { "8553243313" }

    context "as a user" do
      context "when I text" do
        context "given I am offline" do
          let(:offline_user) { create(:offline_user) }

          before do
            create(:message, :user => offline_user)
            send_message(:from => offline_user, :body => "en")
          end

          it "should put me online" do
            offline_user.reload.should be_online
          end
        end

        context "'hello'" do
          context "given there are no matches for me" do
            before do
              send_message(:from => my_number, :body => "hello")
            end

            it "should not reply to me just now as my request for a friend has been already registered" do
              # sending a message that nobody is available is annoying
              reply_to(new_user).should be_nil
            end
          end
        end
      end
    end

    context "as new user" do
      def assert_new_user
        new_user.mobile_number.should == my_number
        new_location.user.should == new_user
        new_location.country_code.should == "kh"
      end

      before do
        load_users
      end

      context "when I text" do

        shared_examples_for "welcoming me" do
          it "should start a chat between myself an existing anonymous user without telling me anything" do
            # I just want to chat!
            assert_new_user

            reply_to(new_user).should be_nil

            reply_to(alex).body.should =~ /^#{spec_translate(:forward_message_approx, alex.locale, new_user.screen_id)}/
          end
        end

        context "'ខ្ងុំចង់ដីង អ្នកជានរណា'" do
          before do
            send_message(:from => my_number, :body => "ខ្ងុំចង់ដីង អ្នកជានរណា")
          end

          it_should_behave_like "welcoming me"
        end

        context "'hello'" do
          before do
            send_message(:from => my_number, :body => "hello")
          end

          it_should_behave_like "welcoming me"

          context "then I text 'en'" do
            before do
              send_message(:from => my_number, :body => "en")
            end

            it "should set my locale to English" do
              new_user.locale.should == :en
            end

            context "then I text 'kh'" do
              before do
                send_message(:from => my_number, :body => "kh")
              end

              it "should set my locale back to Khmer" do
                new_user.locale.should == :kh
              end
            end

            context "then I text 'th'" do
              before do
                send_message(:from => my_number, :body => "th")
              end

              it "should leave my locale in English" do
                new_user.locale.should == :en
              end
            end
          end
        end

        context "'stop'" do
          before do
            send_message(:from => my_number, :body => "stop")
          end

          it "should log me out" do
            reply_to(new_user).should be_nil
          end
        end

        context "'map pros 27 pp jong rok met srey'" do
          before do
            # ensure that joy is the first match by increasing her initiated chat count
            create(:chat, :user => joy)
            send_message(:from => my_number, :body => "map pros 27 pp jong rok met srey", :location => true)
          end

          it "should save me as 'map' a 27 yo male from Phnom Penh and start a chat with a matching female" do
            assert_new_user

            new_user.name.should == "map"
            new_user.age.should == 27
            new_user.location.city.should == "Phnom Penh"
            new_user.looking_for.should == "f"
            new_user.gender.should == "m"

            reply_to(new_user).should be_nil
            reply_to(joy).body.should =~ /^#{spec_translate(:forward_message_approx, joy.locale, new_user.screen_id)}/
          end
        end
      end
    end

    context "as an existing user" do
      before do
        load_users
      end

      context "when I text" do
        context "'23 srey jong rok met pros'" do
          before do
            send_message(:from => alex, :body => "23 srey jong rok met pros")
            alex.reload
          end

          it "should update my profile and find me new friends" do
            alex.name.should == "alex"
            alex.age.should == 23
            alex.gender.should == "f"
            alex.looking_for.should == "m"

            reply_to(alex).should be_nil
            reply_to(dave).body.should =~ /^#{spec_translate(:forward_message_approx, dave.locale, alex.screen_id)}/
          end
        end
      end

      context "given I am currently in a chat session" do
        shared_examples_for "finding me a new friend" do
          context "and later another friend of mine of texts 'Hi Dave'" do
            context "and I am available" do
              before do
                send_message(:from => mara, :body => "Hi Dave")
              end

              it "should send the message to me" do
                reply_to(dave).body.should == spec_translate(
                  :forward_message, dave.locale, mara.screen_id, "Hi Dave"
                )
              end

              context "if I then reply with 'Hi Mara'" do
                before do
                  send_message(:from => dave, :body => "Hi Mara")
                end

                it "should send the message to " do
                  reply_to(mara).body.should == spec_translate(
                    :forward_message, mara.locale, dave.screen_id, "Hi Mara"
                  )
                end
              end
            end
          end
        end

        before do
          initiate_chat(dave, joy)
        end

        context "and my friend doesn't reply to me for a while" do
          before do
            dave.reload.active_chat.deactivate!(:active_user => dave)
          end

          context "and I text" do
            context "'hello'" do
              before do
                send_message(:from => dave, :body => "hello")
              end

              it_should_behave_like "finding me a new friend"
            end
          end
        end

        context "and somebody else tries to text me" do
          # A new match for Mara
          let(:luke) { create(:luke) }

          before do
            luke
            send_message(:from => mara, :body => "Hi Dave")
          end

          it "should find new friends that other person" do
            reply_to(mara).body.should_not == spec_translate(
              :friend_unavailable, mara.locale, dave.screen_id
            )

            reply_to(luke).body.should =~ /^#{spec_translate(:forward_message_approx, luke.locale, mara.screen_id)}/

            reply_to_dave = reply_to(dave)
            reply_to_dave.body.should == spec_translate(
              :forward_message, dave.locale, mara.screen_id, "Hi Dave"
            )
            reply_to_dave.should_not be_delivered
          end

          context "and I send another message" do
            before do
              send_message(:from => dave, :body => "Hi Joy")
            end

            it "should send the message to my current friend" do
              reply_to(joy).body.should == spec_translate(
                :forward_message, joy.locale, dave.screen_id, "Hi Joy"
              )
            end
          end

          context "when I later become available" do
            context "but my old friend is now currently chatting" do
              before do
                send_message(:from => luke, :body => "Hi Mara")
                expect_message { dave.reload.active_chat.deactivate!(:active_user => dave) }
              end

              it "should not send the message that my friend previously sent" do
                reply = reply_to(dave)
                reply.body.should == spec_translate(
                  :forward_message, dave.locale, mara.screen_id, "Hi Dave"
                )
                reply.should_not be_delivered
              end
            end

            context "and my old friend is also available" do
              before do
                expect_message { dave.reload.active_chat.deactivate!(:active_user => dave) }
              end

              it "should send me the message that my old friend previously sent" do
                reply = reply_to(dave)
                reply.body.should == spec_translate(
                  :forward_message, dave.locale, mara.screen_id, "Hi Dave"
                )
                reply.should be_delivered
              end
            end
          end
        end

        context "and I text" do
          context "'new'" do
            before do
              send_message(:from => dave, :body => "new")
            end

            it_should_behave_like "finding me a new friend"

            context "and I text 'new' again" do
              before do
                send_message(:from => dave, :body => "new")
              end

              it "should not tell me that there is nobody currently available" do
                reply_to(dave).body.should_not == spec_translate(
                  :could_not_find_a_friend, dave.locale
                )
              end
            end
          end

          context "'stop'" do
            before do
              send_message(:from => dave, :body => "stop")
            end

            it "should log me out but not notify my friend" do
              reply_to(dave).body.should_not == spec_translate(
                :logged_out_from_chat, dave.locale, joy.screen_id
              )

              reply_to(joy).body.should_not == spec_translate(
                :chat_has_ended, joy.locale
              )
            end
          end

          context "'Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234'" do
            before do
              send_message(:from => dave, :body => "Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234")
              dave.reload
            end

            it "should forward my message to my chat partner" do
              dave.name.should_not == "sok"
              dave.age.should_not == 27
              dave.location.city.should_not == "Kampong Thom"
              dave.mobile_number.should_not == "012232234"
              reply_to(joy).body.should == spec_translate(
                :forward_message, joy.locale, dave.screen_id, "Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234"
              )
            end
          end
        end

        context "and my partner texts" do
          before do
            # joy is already registered so she must have sent one message
            send_message(:from => joy, :body => "hello")
          end

          shared_examples_for "ending my current chat" do
            it "should end my current chat but not give me instructions on how to start a new one" do
              reply_to(dave).body.should_not == spec_translate(
                :chat_has_ended, dave.locale
              )
            end
          end

          context "'new'" do
            before do
              send_message(:from => joy, :body => "new")
            end

            it_should_behave_like "ending my current chat"
          end

          context "'stop'" do
            before do
              send_message(:from => joy, :body => "stop")
            end

            it_should_behave_like "ending my current chat"
          end

          context "'Hi Dave, knyom sara bong nov na?'" do
            before do
              send_message(:from => joy, :body => "Hi Dave, knyom sara bong nov na?")
              joy.reload
            end

            it "should forward her message to me" do
              joy.name.should_not == "sara"
              reply_to(dave).body.should == spec_translate(
                :forward_message, dave.locale, joy.screen_id, "Hi Dave, knyom sara bong nov na?"
              )
            end
          end
        end
      end
    end

    context "as an automated 5 digit short code" do

      let(:user_with_invalid_mobile_number) { build(:user_with_invalid_mobile_number) }

      context "when I text 'some notification'" do
        before do
          send_message(
            :from => user_with_invalid_mobile_number,
            :body => "some notification",
            :response => 400
          )
        end

        it "should not save or process the message" do
          new_message.should be_nil
          new_user.should be_nil
        end
      end
    end
  end
end
