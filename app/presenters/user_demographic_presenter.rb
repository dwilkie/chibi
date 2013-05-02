class UserDemographicPresenter < BasePresenter
  def by_gender
    page_section(:by_gender) do
      table(:headers => [nil, :male, :female, "?", :total]) do
        gender_demographic(:available => true) +
        gender_demographic(:age_range => 0..12, :label => "< 13") +
        gender_demographic(:age_range => 13..17) +
        gender_demographic(:age_range => 18..25) +
        gender_demographic(:age_range => 26..39) +
        gender_demographic(:age_range => 40..80, :label => "> 40") +
        gender_demographic(:with_known_age => true) +
        gender_demographic
      end
    end
  end

  private

  def page_section(id, &block)
    content_tag(:div, :id => id) do
      content_tag(:h2, id.to_s.titleize) +
      yield
    end
  end

  def table(options = {}, &block)
    content_tag(:table) do
      table_content = ""
      if options[:headers]
        table_content +=
        content_tag(:tr) do
          header_row = ""
          options[:headers].each do |header|
            header_row += content_tag(:th, header.to_s.titleize)
          end
          header_row.html_safe
        end
      end
      table_content.html_safe + yield
    end
  end

  def gender_demographic(options = {})
    demographic = User.scoped
    case options.keys.first
    when :available
      demographic = demographic.available
    when :age_range
      options[:label] ||= "#{options[:age_range].min} - #{options[:age_range].max}"
      demographic = demographic.between_the_ages(options[:age_range])
    when :with_known_age
      demographic = demographic.with_date_of_birth
    else
      options[:label] = "Total"
    end

    options[:label] ||= options.keys.first.to_s.titleize

    content_tag(:tr) do
      content_tag(:td, options[:label]) +
      content_tag(:td, demographic.male.count) +
      content_tag(:td, demographic.female.count) +
      content_tag(:td, demographic.without_gender.count) +
      content_tag(:td, demographic.count)
    end
  end
end
