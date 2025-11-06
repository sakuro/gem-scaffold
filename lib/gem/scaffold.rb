# frozen_string_literal: true

require "zeitwerk"
require_relative "scaffold/version"

module Gem
  module Scaffold
    class Error < StandardError; end

    loader = Zeitwerk::Loader.for_gem
    loader.ignore("#{__dir__}/scaffold/version.rb")
    # loader.inflector.inflect(
    #   "html" => "HTML",
    #   "ssl" => "SSL"
    # )
    loader.setup
  end
end
