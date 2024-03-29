require 'rails_helper'

describe "Admin" do
  include MessagingHelpers
  include AdminHelpers
  include CommunicableExampleHelpers
  include CdrHelpers

  let(:user) { create(:user, :male) }
  let(:another_user) { create(:user, :female) }

  let(:chat) { create(:chat, :initiator_active, :user => user, :friend => another_user, :created_at => 10.minutes.ago) }
  let(:another_chat) { create(:chat, :user => another_user, :friend => user, :created_at => 10.minutes.ago) }

  let(:message) { create(:message, :user => another_user, :body => "Hello", :chat => another_chat) }
  let(:another_message) { create(:message, :user => user, :body => "Goodbye", :chat => chat) }

  let(:reply) { create(:reply, :delivered, :user => another_user, :body => "Hello", :chat => another_chat) }
  let(:another_reply) { create(:reply, :user => user, :body => "Goodbye", :chat => chat) }

  let(:phone_call) { create(:phone_call, :user => another_user, :chat => another_chat) }
  let(:another_phone_call) { create(:phone_call, :user => user, :chat => chat) }

  let(:inbound_cdr) { create_cdr(:cdr_variables => {"variables" => {"billsec" => "159"}}) }

  let(:users) { [another_user, user] }
  let(:messages) { [message, another_message] }
  let(:replies) { [reply, another_reply] }
  let(:phone_calls) { [phone_call, another_phone_call] }
  let(:chats) { [another_chat, chat] }
  let(:inbound_cdrs) { inbound_cdr }

  let(:communicable_resources) { [messages, replies, phone_calls] }

  context "without the username and password" do
    it "should deny me access" do
      [overview_path, users_path, chats_path, interaction_path, sidekiq_web_path].each do |path|
        visit path
        expect(page.driver.response.status).to eq(401)
      end
    end
  end

  context "as an admin" do
    before do
      authorize
    end

    def assert_user_index(*resources)
      assert_index :user, *resources, :reverse => true
    end

    def assert_chat_index(*resources)
      assert_index :chat, *resources, :reverse => true
    end

    def total_resources_id(resources_name)
      "#total_#{resources_name}"
    end

    def assert_index(resource_name, *resources)
      options = resources.extract_options!
      resources_name = resource_name.to_s.pluralize
      resources = send(resources_name) if resources.empty?
      resources.reverse! if options[:reverse]

      expect(page.find(
        total_resources_id(resources_name)
      ).text.gsub(/\s/, "")).to eq("#{resources_name.titleize.gsub(/\s/, "")}(#{resources.count})")

      resources.each_with_index do |resource, index|
        within("##{resource_name}_#{index + 1}") do
          send("assert_#{resource_name}_show", resource)
        end
      end
    end

    def assert_show_user(reference_user)
      expect(page.current_path).to eq(user_path(reference_user))
      assert_user_show(reference_user)
    end

    def assert_user_show(reference_user)
      expect(page).to have_css "#id", :text => reference_user.id.to_s
      expect(page).to have_css "#created_at", :text => time_ago_in_words
      expect(page).to have_css "#name", :text => reference_user.name
      expect(page).to have_css "#screen_name", :text => reference_user.screen_name
      expect(page).to have_css "#date_of_birth", :text => reference_user.date_of_birth
      expect(page).to have_css "#gender", :text => reference_user.gender
      expect(page).to have_css "#city", :text => reference_user.city
      expect(page).to have_css "#looking_for", :text => reference_user.looking_for
      expect(page).to have_css "#state", :text => reference_user.state
      expect(page).to have_css "#locale", :text => reference_user.locale
      within "#mobile_number" do
        expect(page).to have_link reference_user.mobile_number, :href => user_path(reference_user)
      end

      assert_communicable_resources_counts(reference_user)
    end

    def assert_chat_show(reference_chat)
      expect(page).to have_css "#id", :text => reference_chat.id.to_s
      expect(page).to have_css "#active", :text => reference_chat.active?
      expect(page).to have_css "#created_at", :text => time_ago_in_words(10)
      expect(page).to have_css "#updated_at", :text => time_ago_in_words

      assert_communicable_resources_counts(reference_chat)

      USER_TYPES_IN_CHAT.each do |user_type|
        within("##{user_type}") do
          reference_user = reference_chat.send(user_type)
          if screen_id = reference_user.try(:screen_id)
            expect(page).to have_link screen_id, :href => user_path(reference_user)
          else
            expect(page).to have_content screen_id
          end
        end
      end
    end

    def time_ago_in_words(created_at = nil)
      minutes_ago = ((Time.current - created_at.to_i.minutes.ago) / 60).round
      minutes_ago.zero? ? "less than a minute ago" : "#{minutes_ago} minutes ago"
    end

    def assert_communicable_resources_counts(resource)
      asserted_communicable_resources.each do |communicable_resources|
        within("##{communicable_resources}") do
          communicable_resources_count = resource.send(communicable_resources).count
          communicable_resources_link = communicable_resources_count.to_s

          if communicable_resources_count.zero?
            expect(page).to have_no_link(communicable_resources_link)
            expect(page).to have_content(communicable_resources_link)
          else
            expect(page).to have_link(
              communicable_resources_link,
              :href => send("#{resource.class.to_s.underscore}_interaction_path", resource)
            )
          end
        end
      end
    end

    def assert_message_show(reference_message)
      expect(page).to have_content reference_message.body
      expect(page).to have_content reference_message.from
      expect(page).to have_content time_ago_in_words
    end

    def assert_reply_show(reference_reply)
      expect(page).to have_content reference_reply.body
      expect(page).to have_content reference_reply.to
      if reference_reply.delivered?
        expect(page).to have_content time_ago_in_words
      else
        expect(page).to have_content "pending"
      end
    end

    def assert_phone_call_show(reference_phone_call)
      expect(page).to have_content time_ago_in_words
      expect(page).to have_link(
        reference_phone_call.from,
        :href => user_path(reference_phone_call.user_id)
      )
      expect(page).to have_content reference_phone_call.state.humanize
    end

    def assert_show_interaction
      [:message, :phone_call].each_with_index do |resource, index|
        within "#interaction_#{index + 1}" do
          send("assert_#{resource}_show", send("another_#{resource}"))
        end
      end
    end

    def assert_navigate_to_interaction(resource_name)
      resources_name = resource_name.to_s.pluralize

      asserted_communicable_resources.each do |communicable_resources|
        visit send("#{resources_name}_path")

        within("##{resource_name}_1 ##{communicable_resources}") do
          click_link(send(resource_name).send(communicable_resources).count.to_s)
        end

        assert_show_interaction
      end
    end

    context "when I visit '/user_demographic'" do
      before do
        visit user_demographic_path
      end

      it "should show me the user demographic" do
        expect(page).to have_content "User Demographic"
      end
    end

    context "when I visit '/overview'" do
      let(:message_from_last_month) { create(:message, :from_last_month, :user => user) }
      let(:reply_from_last_month) { create(:reply, :from_last_month, :user => user) }
      let(:user_from_last_month) { create(:user, :from_last_month) }

      before do
        messages
        message_from_last_month
        replies
        reply_from_last_month
        users
        user_from_last_month
        inbound_cdrs
        visit overview_path
      end

      it "should show me an overview of Chibi" do
        [:day, :month].each do |timeframe|
          within "#timeline_by_#{timeframe}" do
            expect(page).to have_content "Timeline By #{timeframe.to_s.titleize}"
            expect(page).to have_selector "#timeline_by_#{timeframe}_chart"
          end
        end
      end

      context "given it's March 2014" do
        include TimecopHelpers
        include ActiveJobHelpers
        include ReportHelpers

        before do
          stub_redis
          Timecop.freeze(sometime_in(:year => 2014, :month => 3))
        end

        after do
          Timecop.return
        end

        context "and I create a report for February 2014" do
          before do
            visit overview_path
            trigger_job { click_link("create report for February 2014") }
          end

          context "when I visit '/report'" do
            before do
              visit report_path
            end

            it "should download my report" do
              expect(response_headers["Content-Type"]).to eq(asserted_report_type)
              expect(response_headers["Content-Disposition"]).to eq("attachment; filename=\"#{asserted_report_filename(:february, 2014)}\"")
            end
          end
        end
      end
    end

    context "given some chats" do
      before do
        chats
        communicable_resources
      end

      context "when I visit '/chats'" do
        before do
          visit chats_path
        end

        it "should show me a list of chats" do
          assert_chat_index
        end

        context "when I click on screen id for one of the chat participants" do
          it "should show the user" do
            USER_TYPES_IN_CHAT.each do |user_type|
              visit chats_path

              user_resource = chat.send(user_type)

              within("#chat_1 ##{user_type}") do
                click_link(user_resource.screen_id)
              end

              assert_show_user(user_resource)
            end
          end
        end

        context "when I click on the number of communicable resources for one of the chats" do
          it "should show me this user's interaction" do
            assert_navigate_to_interaction(:chat)
          end
        end
      end
    end

    context "given some users" do
      before do
        users
        communicable_resources
      end

      context "when I visit '/users'" do
        before do
          visit users_path
        end

        it "should show me a list of users" do
          assert_user_index
        end

        context "when I click on the number of communicable resources for one of the users" do
          it "should show me this user's interaction" do
            assert_navigate_to_interaction(:user)
          end
        end

        context "when I click on the mobile number for one of the users" do
          before do
            within("#user_1") do
              click_link(user.mobile_number)
            end
          end

          it "should show me the user" do
            assert_show_user(user)
          end
        end
      end
    end

    describe "when I visit '/sidekiq'" do
      before do
        visit sidekiq_web_path
      end

      it "should allow me access" do
        expect(page.driver.response.status).to eq(200)
      end
    end
  end
end
