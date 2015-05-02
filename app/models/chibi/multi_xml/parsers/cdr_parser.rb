require "multi_xml/parsers/nokogiri"

module Chibi
  module MultiXml
    module Parsers
      module CdrParser
        include ::MultiXml::Parsers::Nokogiri
        extend self

        def parse(xml)
          doc = ::Nokogiri::XML(xml)
          node_to_hash(doc.root)
        end
      end
    end
  end
end
