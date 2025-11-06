# frozen_string_literal: true

require "zeitwerk"
require_relative "scaffold/version"

module Gem
  # Gem::Scaffold provides a template for creating Ruby gems with modern best practices.
  #
  # This module serves as the namespace for the gem's functionality.
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
