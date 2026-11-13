#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"

require "dbus"

describe "ByteArrayTest" do
  before(:each) do
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
    @obj = @svc.object("/org/ruby/MyInstance")
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  it "tests passing byte array" do
    data = [0, 77, 255]
    result = @obj.mirror_byte_array(data).first
    expect(result).to eq(data)
  end

  it "tests passing empty byte array" do
    data = []
    result = @obj.mirror_byte_array(data).first
    expect(result).to eq(data)
  end

  it "tests passing byte array from string" do
    data = "AAA"
    result = @obj.mirror_byte_array(data).first
    expect(result).to eq([65, 65, 65])
  end

  it "tests passing empty byte array from string" do
    data = ""
    result = @obj.mirror_byte_array(data).first
    expect(result).to eq([])
  end

  it "tests passing byte array from string with NUL bytes" do
    data = "a\0b".b
    result = @obj.mirror_byte_array(data).first
    expect(result).to eq([97, 0, 98])
  end

  it "tests passing byte array from UTF-8 string according to encoding" do
    data = "ř"
    result = @obj.mirror_byte_array(data).first
    expect(result).to eq(data.bytes)
  end

  it "tests passing a large byte array" do
    data = Array.new(100_000) { |i| i % 256 }
    result = @obj.mirror_byte_array(data).first
    expect(result).to eq(data)
  end

  it "tests passing byte array from hash" do
    # Hash is an Enumerable, but is caught earlier
    data = { "this will" => "fail" }
    expect { @obj.mirror_byte_array(data).first }.to raise_error(DBus::TypeException)
  end

  it "tests passing byte array from nonenumerable" do
    data = Time.now
    expect { @obj.mirror_byte_array(data).first }.to raise_error(DBus::TypeException)
  end
end
