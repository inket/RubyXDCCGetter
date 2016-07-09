require_relative "helper"
require_relative "xlogger"
require "cinch"

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

    XLogger.puts "Starting bot..."
    self.bot_thread = Thread.new(bot, &:start)

    XLogger.puts "Connecting..."

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
    XLogger.puts "Connected."
    self.connected = true
    ask_for_dl
  end

  def ask_for_dl
    return unless connected &&
                  waiting_download &&
                  waiting_download[:requested].nil?

    XLogger.puts "Asking #{waiting_download[:user]} "\
                "for download #{waiting_download[:file]}..."

    User(waiting_download[:user]).send("xdcc send #{waiting_download[:file]}")
    self.waiting_download[:requested] = true
  end

  listen_to :private, method: :on_msg
  def on_msg(m)
    XLogger.puts m.message
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
        XLogger.puts "Received response:"
        XLogger.puts "*File: #{filename}"
        XLogger.puts "*Size: #{Helper.human_size(filesize)}\n\n"

        XLogger.puts "Starting download..."

        download_thread = create_download_thread(dcc, download_folder)
        progress_thread = create_progress_thread(download_thread)

        XLogger.puts "Download started."

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
      XLogger.puts "Ignoring XDCC request from '#{dcc.user.nick}' as it is not expected."
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
      XLogger.puts "Download finished."
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

  def download_info
    return nil unless download && download[:progress_thread]["total_size"]

    {
      filename: download[:filename],
      downloading: download[:download_thread].alive?,
      progress: download[:progress_thread]["progress"] || 0,
      speed: download[:progress_thread]["speed"],
      size: download[:progress_thread]["size"],
      total_size: download[:progress_thread]["total_size"]
    }
  end
end
