# frozen_string_literal: true

# Minimal GTK app exporting a StatusNotifierItem with IconPixmap (a(iiay)) over
# ruby-dbus, to compare old per-element ay marshalling vs the fast path.

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))

require "gtk4"
require "dbus"

def icon_pixmaps
  [64, 128].map { |size| [size, size, Array.new(size * size * 4) { |i| (i * 31 + size) & 0xFF }] }
end

class StatusNotifierItem < DBus::Object
  def initialize(path, pixmaps)
    @category = "SystemServices"
    @id = "org.ruby_dbus.bench.ay"
    @title = "ruby-dbus ay bench"
    @status = "Active"
    @icon_name = ""
    @icon_pixmap = pixmaps
    @icon_theme_path = ""
    @menu = "/StatusNotifierItem/Menu"
    @item_is_menu = false
    @tool_tip = ["", pixmaps.first || [0, 0, []], "ruby-dbus ay bench", ""]
    super(path)
  end

  %w[org.freedesktop.StatusNotifierItem org.kde.StatusNotifierItem].each do |iface|
    dbus_interface iface do
      dbus_attr_reader :category, "s"
      dbus_attr_reader :id, "s"
      dbus_attr_reader :title, "s"
      dbus_attr_reader :status, "s"
      dbus_attr_reader :icon_name, "s"
      dbus_attr_reader :icon_pixmap, "a(iiay)"
      dbus_attr_reader :icon_theme_path, "s"
      dbus_attr_reader :menu, "o"
      dbus_attr_reader :item_is_menu, "b"
      dbus_attr_reader :tool_tip, "(sa(iiay)ss)"

      dbus_method(:Activate, "in x:i, in y:i") { |_x, _y| }
      dbus_method(:SecondaryActivate, "in x:i, in y:i") { |_x, _y| }
      dbus_method(:ContextMenu, "in x:i, in y:i") { |_x, _y| }
      dbus_method(:Scroll, "in delta:i, in orientation:s") { |_d, _o| }
    end
  end
end

class BenchApp < Gtk::Application
  def initialize
    super("org.ruby_dbus.bench.ay", :flags_none)
    signal_connect("activate") do
      bus = DBus.session_bus
      service_name = "org.freedesktop.StatusNotifierItem-#{Process.pid}-1"
      service = bus.request_service(service_name)
      service.export(StatusNotifierItem.new("/StatusNotifierItem", icon_pixmaps))

      Thread.new do
        begin
          watcher = bus.service("org.kde.StatusNotifierWatcher").object("/StatusNotifierWatcher")
          watcher.default_iface = "org.kde.StatusNotifierWatcher"
          watcher.RegisterStatusNotifierItem(service_name)
        rescue StandardError
        end
        main = DBus::Main.new
        main << bus
        main.run
      rescue StandardError
      end

      win = Gtk::ApplicationWindow.new(self)
      win.title = "ruby-dbus ay benchmark"
      win.set_default_size(200, 80)
      win.present
    end
  end
end
