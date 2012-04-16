module ApplicationHelper
  def heading_with_count(resources, count)
    capture_haml do
      haml_tag :h2, :id => "total_#{resources}" do
        haml_concat "#{resources.to_s.titleize} (#{count})"
      end
    end
  end
end
