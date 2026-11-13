#!/usr/bin/env ruby
# frozen_string_literal: true

# Run the GTK SNI benchmark app using the NEW fast-path ay marshalling
# (current implementation in ../../lib).

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dbus"
require_relative "app"

BenchApp.new.run
