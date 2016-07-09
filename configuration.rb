class Configuration
  attr_accessor :server, :bot_name, :file_number,
                :channel_name, :download_folder, :log_file

  def self.argument_value(argument)
    index = ARGV.index(argument)
    index ? ARGV[index + 1] : nil
  end

  def self.argument_path(argument)
    value = argument_value(argument)
    value ? File.expand_path(value) : nil
  end

  def initialize
    self.server, self.bot_name, self.file_number = ARGV

    self.channel_name = Configuration.argument_value("-c")
    self.download_folder = Configuration.argument_path("-d")
    self.log_file = Configuration.argument_path("-o")
  end

  def print
    channel = "##{channel_name}" if channel_name

    puts "Your parameters:"
    puts "*Server: #{server}"
    puts "*Bot name: #{bot_name}"
    puts "*Requested file: #{file_number}"
    puts "*Join channel: #{channel || '<none>'}"
    puts "*Download folder: #{download_folder || 'here!'}"
    puts "*Bot log file: #{log_file || '<none>'}"
    puts
  end

  def print_usage
    puts "Usage: ruby xdcc.rb <server> <bot_name> <file_number> "\
         "[-c <channel_name>] [-d <download_folder>] [-o <bot_log_file>]"
    puts "Example: ruby xdcc.rb irc.rizon.net Cerebrate 321 -c horriblesubs "\
         "-d '~/Downloads/' -o bot.log"
  end

  def valid?
    unless server && bot_name && file_number
      return false
    end

    if download_folder && !File.directory?(download_folder)
      puts "'#{download_folder}' is not a folder."
      return false
    end

    if log_file && File.directory?(log_file)
      puts "#{log_file} is a folder."
      return false
    end

    true
  end
end
