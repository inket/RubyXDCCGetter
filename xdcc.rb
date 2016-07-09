#!/usr/bin/env ruby

require_relative "helper"
require_relative "xlogger"
require_relative "configuration"
require_relative "bot"

Config = Configuration.new

if Config.valid?
  Config.print
else
  Config.print_usage
  exit
end

XLogger.switch_output(Config.log_file)

begin
  xdcc = XDCC.new(Config.server, Config.channel_name)
  xdcc.handler.download_folder = Config.download_folder
  xdcc.handler.start_download(Config.bot_name, Config.file_number)

  while xdcc.bot_thread.alive? &&
        (xdcc.handler.download_info.nil? ||
         xdcc.handler.download_info[:downloading])
    sleep 1

    info = xdcc.handler.download_info
    next unless info

    filename = info[:filename]
    size = Helper.human_size(info[:size])
    total_size = Helper.human_size(info[:total_size])
    progress = info[:progress]
    speed = Helper.human_size(info[:speed])

    XLogger.puts "#{filename}: #{size}/#{total_size} (#{progress}%) - #{speed}/s"
  end

  XLogger.puts "Finished download. Quitting..."
  xdcc.bot.quit

  XLogger.restore_output
rescue Interrupt
  XLogger.restore_output
  puts "User cancelled download. Quitting..."
rescue Exception => e
  XLogger.restore_output
  raise e
end
