require 'spec_helper'

describe "Report" do
  include AuthenticationHelpers
  include ResqueHelpers
  include ReportHelpers

  before do
    stub_redis
  end

  def report_path
    super(:format => :json)
  end

  def authentication_params
    super(:admin)
  end

  def report_params(params = {})
    {:report => params}
  end

  def post_report(params = {})
    post(
      report_path,
      report_params(params),
      authentication_params
    )
  end

  describe "POST '/report.json'" do
    context "with valid params" do
      before do
        post_report(:month => 1, :year => 2014)
      end

      it "should queue a job to generate a report" do
        ReportGenerator.should have_queued("year" => "2014", "month" => "1")
      end

      it "should return a 201" do
        response.status.should be(201)
      end
    end

    context "with invalid params" do
      before do
        post_report(:year => 2014)
      end

      it "should not queue a job to generate a report" do
        ReportGenerator.should_not have_queued("year" => "2014")
      end

      it "should return a 400" do
        response.status.should be(400)
      end
    end
  end

  describe "GET '/report.json'" do
    def get_report
      get(
        report_path,
        {},
        authentication_params
      )
    end

    context "given the report has not yet been generated" do
      before do
        get_report
      end

      it "should return a 404" do
        response.status.should be(404)
      end
    end

    context "given the report has already been generated" do
      before do
        post_report(:year => 2014, :month => 1)
        perform_background_job(:report_generator_queue)
        get_report
      end

      it "should return a 200" do
        response.status.should be(200)
      end

      it "should return the generated report" do
        parsed_response = JSON.parse(response.body)
        parsed_response["month"].should == "1"
        parsed_response["year"].should == "2014"
      end
    end
  end
end
