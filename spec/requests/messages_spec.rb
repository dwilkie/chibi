# encoding: utf-8

require 'rails_helper'

describe "Messages" do

  describe "POST /messages" do
    include MessagingHelpers
    include TranslationHelpers

    include_context "existing users"
    include_context "replies"

    let(:new_user) { User.last }
    let(:new_location) { Location.last }
    let(:new_message) { Message.last }

    let(:my_number) { "855977123876" }

    context "as a user" do
      context "when I text" do
        context "given I am offline" do
          let(:offline_user) { create(:user, :offline) }

          before do
            create(:message, :user => offline_user)
            send_message(:from => offline_user, :body => "en")
          end

          it "should put me online" do
            expect(offline_user.reload).to be_online
          end
        end

        context "'hello'" do
          context "given there are no matches for me" do
            before do
              send_message(:from => my_number, :body => "hello")
            end

            it "should not reply to me just now as my request for a friend has been already registered" do
              # sending a message that nobody is available is annoying
              expect(reply_to(new_user)).to be_nil
            end
          end
        end
      end
    end

    context "as new user" do
      def assert_new_user
        expect(new_user.mobile_number).to eq(my_number)
        expect(new_location.user).to eq(new_user)
        expect(new_location.country_code).to eq("kh")
      end

      before do
        load_users
      end

      context "when I text" do

        shared_examples_for "welcoming me" do
          it "should start a chat between myself an existing anonymous user without telling me anything" do
            # I just want to chat!
            assert_new_user

            expect(reply_to(new_user)).to be_nil

            expect(reply_to(alex).body).to match(/#{spec_translate(:forward_message_approx, alex.locale, new_user.screen_id)}/)
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
        end

        context "'stop'" do
          before do
            send_message(:from => my_number, :body => "stop")
          end

          it "should log me out" do
            expect(reply_to(new_user)).to be_nil
          end
        end

        context "'chhmous map pros 27 pp jong rok met srey'" do
          before do
            # ensure that joy is the first match by increasing her initiated chat count
            create(:chat, :user => joy)
            send_message(:from => my_number, :body => "chhmous map pros 27 pp jong rok met srey", :location => true)
          end

          it "should save me as 'map' a 27 yo male from Phnom Penh and start a chat with a matching female" do
            assert_new_user

            expect(new_user.name).to eq("map")
            expect(new_user.age).to eq(27)
            expect(new_user.location.city).to eq("Phnom Penh")
            expect(new_user.gender).to eq("m")

            expect(reply_to(new_user)).to be_nil
            expect(reply_to(joy).body).to match(/#{spec_translate(:forward_message_approx, joy.locale, new_user.screen_id)}/)
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
            expect(alex.name).to eq("alex")
            expect(alex.age).to eq(23)
            expect(alex.gender).to eq("f")

            expect(reply_to(alex)).to be_nil
            expect(reply_to(dave).body).to match(/#{spec_translate(:forward_message_approx, dave.locale, alex.screen_id)}/)
          end
        end
      end

      context "given I search for a new friend" do
        before do
          initiate_chat(dave)
        end

        context "then Pauline searches for a new friend" do
          let(:pauline) { create(:pauline) }

          before do
            initiate_chat(pauline)
          end

          context "then Mara texts 'Hi Dave'" do
            before do
              send_message(:from => mara, :body => "Hi Dave")
            end

            it "should forward Mara's message to me" do
              reply = reply_to(dave)
              expect(reply.body).to eq(spec_translate(
                :forward_message, dave.locale, mara.screen_id, "Hi Dave"
              ))
              expect(reply).to be_delivered
            end

            context "then I text 'Hi how are you?'" do
              before do
                send_message(:from => dave, :body => "Hi how are you?")
              end

              it "should forward the message to Mara" do
                reply = reply_to(mara)
                expect(reply.body).to eq(spec_translate(
                  :forward_message, mara.locale, dave.screen_id, "Hi how are you?"
                ))
                expect(reply).to be_delivered
              end
            end

            context "then I text 'Hi Pauline how are you?'" do
              before do
                send_message(:from => dave, :body => "Hi Pauline how are you?")
              end

              it "should forward the message to Pauline" do
                reply = reply_to(pauline)
                expect(reply.body).to eq(spec_translate(
                  :forward_message, pauline.locale, dave.screen_id, "Hi Pauline how are you?"
                ))
                expect(reply).to be_delivered
              end

              context "and Pauline texts 'Good thanks and you?'" do
                before do
                  send_message(:from => pauline, :body => "Good thanks and you?")
                end

                it "should forward the message to me" do
                  reply = reply_to(dave)
                  expect(reply.body).to eq(spec_translate(
                    :forward_message, dave.locale, pauline.screen_id, "Good thanks and you?"
                  ))
                  expect(reply).to be_delivered
                end
              end

              context "and Mara texts 'Good thanks and you?'" do
                before do
                  send_message(:from => mara, :body => "Good thanks and you?")
                end

                it "should forward the message to me but not deliver it because I chose to chat with Pauline" do
                  reply = reply_to(dave)
                  expect(reply.body).to eq(spec_translate(
                    :forward_message, dave.locale, mara.screen_id, "Good thanks and you?"
                  ))
                  expect(reply).not_to be_delivered
                end
              end
            end
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
                expect(reply_to(dave).body).to eq(spec_translate(
                  :forward_message, dave.locale, mara.screen_id, "Hi Dave"
                ))
              end

              context "if I then reply with 'Hi Mara'" do
                before do
                  send_message(:from => dave, :body => "Hi Mara")
                end

                it "should send the message to mara" do
                  expect(reply_to(mara).body).to eq(spec_translate(
                    :forward_message, mara.locale, dave.screen_id, "Hi Mara"
                  ))
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

        context "and Mara tries to text me" do
          # A new match for Mara
          let(:luke) { create(:luke) }

          before do
            luke
            send_message(:from => mara, :body => "Hi Dave")
          end

          let(:reply_to_dave) { reply_to(dave) }

          it "should find new friends for her" do
            expect(reply_to(luke).body).to match(/#{spec_translate(:forward_message_approx, luke.locale, mara.screen_id)}/)

            expect(reply_to_dave.body).to eq(spec_translate(
              :forward_message, dave.locale, mara.screen_id, "Hi Dave"
            ))
            expect(reply_to_dave).not_to be_delivered
          end

          context "and I send another message" do
            let(:pauline) { create(:pauline) }

            before do
              pauline
              send_message(:from => dave, :body => "Hi Joy")
            end

            shared_examples_for "forwarding the message" do |options|
              options ||= {}

              it "should send the message to my current friend" do
                expect(reply_to(joy).body).to eq(spec_translate(
                  :forward_message, joy.locale, dave.screen_id, "Hi Joy"
                ))
                expect(reply_to(pauline)).to be_nil
              end

              if options[:deliver_message_from_mara]
                it "should now deliver Mara's message to me" do
                  expect(reply_to_dave).to be_delivered
                end
              else
                it "should not deliver Mara's message to me" do
                  expect(reply_to_dave).not_to be_delivered
                end
              end
            end

            it_should_behave_like "forwarding the message"

            context "and another" do
              before do
                send_message(:from => dave, :body => "Hi Joy")
              end

              it_should_behave_like "forwarding the message"

              context "and another" do
                before do
                  send_message(:from => dave, :body => "Hi Joy")
                end

                it_should_behave_like "forwarding the message", :deliver_message_from_mara => true
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
          end

          context "'stop'" do
            before do
              send_message(:from => dave, :body => "stop")
            end

            it "should log me out" do
              expect(dave.reload).not_to be_online
            end
          end

          context "'Hi nyom chhmous mara 27 nov kt want 2 chat with me? 012 232 234'" do
            before do
              send_message(
                :from => dave, :body => "Hi nyom chhmous mara 27 nov kt want 2 chat with me? 012 232 234",
                :location => true, :cassette => "kh/kampong_thum"
              )
              dave.reload
            end

            it "should forward my message to my chat partner and update my profile" do
              expect(dave.name).to eq("mara")
              expect(dave.age).to eq(27)
              expect(dave.location.city).to eq("Kampong Thom")
              expect(dave.mobile_number).not_to eq("012232234")
              expect(reply_to(joy).body).to eq(spec_translate(
                :forward_message, joy.locale, dave.screen_id, "Hi nyom chhmous mara 27 nov kt want 2 chat with me? 012 232 234"
              ))
            end
          end
        end

        context "and my partner texts" do
          before do
            # joy is already registered so she must have sent one message
            send_message(:from => joy, :body => "hello")
          end

          context "'new'" do
            before do
              send_message(:from => joy, :body => "new")
            end

            it "should keep me in the chat with joy" do
              expect(dave.reload).to be_currently_chatting
              expect(joy.reload).not_to be_currently_chatting
            end
          end

          context "'stop'" do
            before do
              send_message(:from => joy, :body => "stop")
            end

            it "should keep joy in the chat with me" do
              expect(dave.reload).not_to be_currently_chatting
              expect(joy.reload).to be_currently_chatting
            end
          end

          context "'Sara: Hi Dave, knyom sara bong nov na?'" do
            before do
              send_message(:from => joy, :body => "Sara: Hi Dave, knyom sara bong nov na?")
              joy.reload
            end

            it "should forward her message to me" do
              expect(joy.name).to eq("sara")
              expect(reply_to(dave).body).to eq(spec_translate(
                :forward_message, dave.locale, joy.screen_id, "Hi Dave, knyom sara bong nov na?"
              ))
            end
          end
        end
      end
    end

    context "as an automated 5 digit short code" do

      let(:user_with_invalid_mobile_number) { build(:user, :with_invalid_mobile_number) }

      context "when I text 'some notification'" do
        before do
          send_message(
            :from => user_with_invalid_mobile_number,
            :body => "some notification",
            :response => 400
          )
        end

        it "should not save or process the message" do
          expect(new_message).to be_nil
          expect(new_user).to be_nil
        end
      end
    end

    context "as nuntium" do
      context "when I post a duplicate to the server" do
        let(:message_with_guid) { create(:message, :with_guid) }

        before do
          send_message(
            :from => message_with_guid.user,
            :guid => message_with_guid.guid,
            :response => 400
          )
        end

        it "should not save or process the message" do
          expect(new_message).to eq(message_with_guid)
        end
      end
    end
  end
end
