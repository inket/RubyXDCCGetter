require "cinch"

class Helper
  attr_accessor :stdout, :stderr

  # bytes -> human readable size
  def human_size(n, base = 8)
    return "0" if n.nil?

    units = %w(B KB MB GB)

    unit = units[0]
    size = n

    if n.instance_of?(String)
      unit = n[-2, 2]
      size = n[0..-2].to_f
    end

    if (size >= 1024 && base == 8) || (size >= 1000 && base == 10)
      human_size((base == 8 ? (size / 1024) : (size / 1000)).to_s + units[units.index(unit) + 1], base)
    else
      if size == size.to_i
        return size.to_i.to_s + unit
      else
        index = size.to_s.index(".")

        return size.to_s[0..(index - 1)] + unit if units.index(unit) < 2

        begin
          return size.to_s[0..(index + 2)] + unit
        rescue
          return size.to_s[0..(index + 1)] + unit
        end
      end
    end
  end

  def switch_output(log_path = nil)
    if log_path.nil?
      STDOUT.reopen("/dev/null", "w")
    else
      STDOUT.reopen(log_path, "w")
    end
    STDERR.reopen(STDOUT)
    $stdout = STDOUT
    $stderr = STDOUT
    STDOUT.sync = true

    self.stdout = IO.new(IO.sysopen("/dev/tty", "a+"))
    self.stdout.sync = true
  end

  def puts(str)
    self.stdout.puts str
  end

  def restore_output
    STDOUT.reopen("/dev/tty")
    STDOUT.sync = true
    STDERR.reopen(STDOUT)
    STDERR.sync = true
  end
end

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

class XDCC
  attr_accessor :bot, :bot_thread
  attr_accessor :handler

  def initialize(server, optional_channel)
    self.bot = Cinch::Bot.new do
      configure do |c|
        c.server = server
        c.nick = "Guest" + Time.now.to_f.to_s.delete(".")[10..-1]
        c.channels = ["##{optional_channel}"] if optional_channel
        c.plugins.plugins = [XDCCHandler]
      end
    end

    H.puts "Starting bot..."
    self.bot_thread = Thread.new(bot, &:start)

    H.puts "Connecting..."

    while bot.plugins.first.nil?
      sleep 1 # waiting for connection
    end
    self.handler = bot.plugins.first
  end
end

class XDCCHandler
  include Cinch::Plugin
  attr_accessor :download
  attr_accessor :connected, :waiting_download
  attr_accessor :download_folder

  def start_download(user, file)
    self.waiting_download = { user: user, file: file }
    ask_for_dl
  end

  listen_to :connect, method: :on_connect
  def on_connect(_m)
    H.puts "Connected."
    self.connected = true
    ask_for_dl
  end

  def ask_for_dl
    return unless connected &&
                  waiting_download &&
                  waiting_download[:requested].nil?

    H.puts "Asking #{waiting_download[:user]} "\
           "for download #{waiting_download[:file]}..."

    User(waiting_download[:user]).send("xdcc send #{waiting_download[:file]}")
    self.waiting_download[:requested] = true
  end

  listen_to :dcc_send, method: :incoming_dcc
  def incoming_dcc(_m, dcc)
    if waiting_download
      user = waiting_download[:user].downcase
      file = waiting_download[:file]

      remote_user = dcc.user.nick.downcase
      filename = dcc.filename
      filesize = dcc.size

      if user == remote_user
        H.puts "Received response:"
        H.puts "*File: #{filename}"
        H.puts "*Size: #{H.human_size(filesize)}\n\n"

        H.puts "Starting download..."

        download_thread = create_download_thread(dcc, download_folder)
        progress_thread = create_progress_thread(download_thread)

        H.puts "Download started."

        self.download = {
          user: user,
          file: file,
          filename: filename,
          download_thread: download_thread,
          progress_thread: progress_thread
        }

        self.waiting_download = nil
      end
    else
      H.puts "Ignoring XDCC request from '#{dcc.user.nick}' as it is not expected."
    end
  end

  def create_download_thread(dcc_, download_dir_ = "")
    download_dir_ ||= ""

    Thread.new(dcc_, download_dir_) do |dcc, download_dir|
      Thread.current["dcc"] = dcc
      Thread.current["download_dir"] = download_dir

      save_path = "#{download_dir}#{dcc.filename}"
      Thread.current["file"] = save_path

      t = File.open(save_path.to_s, "w")
      dcc.accept(t)
      H.puts "Download finished."
      t.close
    end
  end

  def create_progress_thread(download_thread)
    Thread.new(download_thread) do |dl_thread|
      sleep 2
      dcc = dl_thread["dcc"]
      file = dl_thread["file"]

      total_size = dcc.size || 0
      size = 0

      Thread.current["total_size"] = total_size

      while dl_thread.alive?
        sleep 1 # limit progress check to once/2sec

        new_size = File.size(file)
        Thread.current["speed"] =  new_size - size
        Thread.current["progress"] = (total_size != 0 ? ((new_size.to_f / total_size.to_f) * 100).to_i : 0)
        Thread.current["size"] = new_size

        size = new_size
      end
    end
  end

  def download
    if @download && @download[:progress_thread]["total_size"]
      {
        filename: @download[:filename],
        downloading: @download[:download_thread].alive?,
        progress: @download[:progress_thread]["progress"] || 0,
        speed: @download[:progress_thread]["speed"],
        size: @download[:progress_thread]["size"],
        total_size: @download[:progress_thread]["total_size"]
      }
    end
  end
end

Config = Configuration.new

if Config.valid?
  Config.print
else
  Config.print_usage
  exit
end

H = Helper.new
H.switch_output(Config.log_file)

begin
  xdcc = XDCC.new(Config.server, Config.channel_name)
  xdcc.handler.download_folder = Config.download_folder
  xdcc.handler.start_download(Config.bot_name, Config.file_number)

  while xdcc.bot_thread.alive? &&
        (xdcc.handler.download.nil? || xdcc.handler.download[:downloading])
    sleep 1

    download = xdcc.handler.download
    next unless download

    H.puts "#{download[:filename]}: "\
           "#{H.human_size(download[:size])}/#{H.human_size(download[:total_size])} "\
           "(#{download[:progress]}%) - #{H.human_size(download[:speed])}/s"
  end

  H.puts "Finished download. Quitting..."
  xdcc.bot.quit

  H.restore_output
rescue Interrupt
  H.restore_output
  puts "User cancelled download. Quitting..."
rescue Exception => e
  H.restore_output
  raise e
end
