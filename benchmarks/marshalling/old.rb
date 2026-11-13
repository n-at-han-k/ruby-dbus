#!/usr/bin/env ruby
# frozen_string_literal: true

# Run the GTK SNI benchmark app using the OLD per-element ay marshalling.

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dbus"

# Restore pre-fast-path byte-array marshalling: per-element append for ay.
module DBus
  class PacketMarshaller
    def append_array(child_type, val)
      if val.is_a?(Hash)
        raise TypeException, "Expected an Array but got a Hash" if child_type.sigtype != Type::DICT_ENTRY
        val = val.to_a
      end
      if val.is_a?(String) && child_type.sigtype == Type::BYTE
        val = val.bytes
      end
      if !val.is_a?(Enumerable)
        raise TypeException, "Expected an Enumerable of #{child_type.inspect} but got a #{val.class}"
      end

      array(child_type) do
        val.each do |elem|
          append(child_type, elem)
        end
      end
    end
  end
end

require_relative "app"

BenchApp.new.run
