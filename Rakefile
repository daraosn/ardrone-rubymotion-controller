# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project'
require 'rubygems'
require 'bundler'
Bundler.require(:RubyMotion)

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'ardrone'
  app.frameworks += ["CFNetwork", "CoreServices", "CoreGraphics"]
  app.files = (app.files - Dir.glob('./app/**/*.rb')) + Dir.glob("./lib/**/*.rb") + Dir.glob("./config/**/*.rb") + Dir.glob("./app/**/*.rb")
  app.interface_orientations = [:landscape_right]

  app.pods do
    pod 'CocoaAsyncSocket'
  end
end
