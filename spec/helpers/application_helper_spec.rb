require 'rails_helper'

describe ApplicationHelper do
  include CommunicableExampleHelpers

  before do
    helper.extend Haml
    helper.extend Haml::Helpers
    helper.send :init_haml_helpers
  end

  describe "#communicable_links" do
    def assert_communicable_content(resource, resource_name)
      asserted_communicable_resources.each do |communicable_resources|
        communicable_resources_count = resource.send(communicable_resources).count
        output = helper.communicable_links(resource)
        xpath = "//td[@id='#{communicable_resources}']"
        expected_text = communicable_resources_count.to_s
        if communicable_resources_count.zero?
          expect(output).to have_xpath(xpath, :text => expected_text)
        else
          expect(output).to have_xpath(
            "#{xpath}/a[@href='/#{resource_name.to_s.pluralize}/#{resource.id}/interaction']",
            :text => expected_text
          )
        end
      end
    end

    def assert_communicable_links(resource_class, resource_name)
      reference_resource = resource_class.filter_by.first
      assert_communicable_content(reference_resource, resource_name)
      resource = create(resource_name)
      asserted_communicable_resources.each do |communicable_resources|
        create(communicable_resources.to_s.singularize, resource_name => resource)
      end
      reference_resource = resource_class.filter_by.first
      assert_communicable_content(reference_resource, resource_name)
    end

    it "should return a link for the communicable resource" do
      [User, Chat].each do |resource_class|
        resource_name = resource_class.to_s.underscore.to_sym
        create(resource_name)
        assert_communicable_links(resource_class, resource_name)
      end
    end
  end

  describe "#heading_with_count" do
    it "should return a h2 heading with the resource and the count" do
      expect(helper.heading_with_count(:phone_calls, 5)).to have_css(
        "h2#total_phone_calls", :text => "Phone Calls (5)"
      )
    end
  end
end
