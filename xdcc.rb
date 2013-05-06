class Helper
	attr_accessor :stdout, :stderr

	# bytes -> human readable size
	def self.human_size(n, base = 8)
		return "0" if n.nil?
		
		units = ["B", "KB", "MB", "GB"]
	
		unit = units[0]
		size = n
	
		if (n.instance_of?String)
			unit = n[-2, 2]
			size = n[0..-2].to_f
		end
	
		if ((size >= 1024 && base == 8) || (size >= 1000 && base == 10))
			human_size((base==8?(size/1024):(size/1000)).to_s+units[units.index(unit)+1], base)
		else
			if (size == size.to_i)
				return size.to_i.to_s+unit
			else
				index = size.to_s.index(".")
				
				return size.to_s[0..(index-1)]+unit if units.index(unit) < 2
				
				begin
					return size.to_s[0..(index+2)]+unit
				rescue
					return size.to_s[0..(index+1)]+unit
				end
			end
		end
	end

	def switch_output(log_path = nil)
		if (log_path.nil?)
			STDOUT.reopen("/dev/null", "w")
		else
			STDOUT.reopen(log_path, "w")
		end
		STDERR.reopen(STDOUT)
		$stdout = STDOUT
		$stderr = STDOUT
		STDOUT.sync = true

		@stdout = IO.new(IO.sysopen("/dev/tty", "a+"))
		@stdout.sync = true
	end

	def puts(str)
		@stdout.puts str
	end

	def restore_output
		STDOUT.reopen("/dev/tty")
		STDOUT.sync = true
		STDERR.reopen(STDOUT)
		STDERR.sync = true
	end
end

if (ARGV[0..2].compact.size < 3)
	puts "Usage: ruby xdcc.rb <server> <bot_name> <file_number> [-c <channel_name>] [-d <download_folder>] [-o <bot_log_file>]"
	puts "Example: ruby xdcc.rb irc.rizon.net Cerebrate 321 -c horriblesubs -d '~/Downloads/' -o bot.log"
	exit
end

i = 0
@@server = nil
@@bot_name = nil
@@file_number = nil
@@channel_name = nil
@@download_folder = nil
@@log_file = nil

ARGV.delete_if {
	|x|

	if (i == 0)
		@@server = x
	elsif (i == 1)
		@@bot_name = x
	elsif (i == 2)
		@@file_number = x
	else
		if (x == "-d")
			ARGV.shift
			@@download_folder = File.expand_path(ARGV.first)+"/"
			if (!File.directory?(@@download_folder))
				puts "'#{@@download_folder}' is not a folder."
				exit
			end
		elsif (x == "-c")
			ARGV.shift
			@@channel_name = ARGV.first
		elsif (x == "-o")
			ARGV.shift
			@@log_file = File.expand_path(ARGV.first)
			if (File.directory?(@@log_file))
				puts "#{@@log_file} is a folder."
				exit
			end
		end
	end

	i+=1
	true
}

puts "Your parameters:"
puts "*Server: #{@@server}"
puts "*Bot name: #{@@bot_name}"
puts "*Requested file: #{@@file_number}"
puts "*Join channel: #{'#' if @@channel_name}#{@@channel_name || '<none>'}"
puts "*Download folder: #{@@download_folder || 'here!'}"
puts "*Bot log file: #{@@log_file || '<none>'}"
puts "\n\n"

begin
	Gem::Specification::find_by_name("cinch")
rescue Exception => e
	puts "This script requires ruby >=1.9.1 and the gem 'cinch'."
	puts e
	exit
end

@@helper = Helper.new
@@helper.switch_output(@@log_file)

require 'cinch'

class XDCC
	attr :bot, :bot_thread
	attr_reader :handler

	def initialize(server, optional_channel)
		@bot = Cinch::Bot.new do
			configure do |c|
				c.server = server || "irc.rizon.net"
				c.nick = "Guest"+Time.now.to_f.to_s.gsub(".", "")[10..-1]
				c.channels = ["##{optional_channel}"] if optional_channel
				c.plugins.plugins = [XDCCHandler]
			end
		end

		@@helper.puts "Starting bot..."
		@bot_thread = Thread.new(@bot) {
			|bot|
			bot.start
		}

		@@helper.puts "Connecting..."

		while (@bot.plugins.first.nil?)
			sleep 1 # waiting for connection
		end
		@handler = @bot.plugins.first
	end
end

class XDCCHandler
	include Cinch::Plugin
	attr :download
	attr_reader :connected, :waiting_download
	attr_accessor :download_folder

	def start_download(user, file)
		@waiting_download = {:user => user, :file => file}
		ask_for_dl
	end

	listen_to :connect, method: :on_connect
	def on_connect(m)
		@@helper.puts "Connected."
		@connected = true
		ask_for_dl
	end

	def ask_for_dl
		if (@connected && @waiting_download && @waiting_download[:requested].nil?)
			@@helper.puts "Asking #{@waiting_download[:user]} for download #{@waiting_download[:file]}..."
			User(@waiting_download[:user]).msg("xdcc send #{@waiting_download[:file]}")
			@waiting_download[:requested] = true
		end
	end

	# listen_to :message, method: :on_message
	# def on_message(m)
	# 	puts "MESSAGE: "+m.inspect
	# end

	listen_to :dcc_send, method: :incoming_dcc
	def incoming_dcc(m, dcc)
		if (@waiting_download)
			user = @waiting_download[:user].downcase
			file = @waiting_download[:file]

			remote_user = dcc.user.nick.downcase
			filename = dcc.filename
			filesize = dcc.size

			if (user == remote_user)
				@@helper.puts "Received response:"
				@@helper.puts "*File: #{filename}"
				@@helper.puts "*Size: #{Helper.human_size(filesize)}\n\n"

				@@helper.puts "Starting download..."

				download_thread = create_download_thread(dcc, @download_folder)
				progress_thread = create_progress_thread(download_thread)

				@@helper.puts "Download started."

				@download = {:user => user, :file => file, :filename => filename,
					:download_thread => download_thread,
					:progress_thread => progress_thread
				}

				@waiting_download = nil
			end
		else
			@@helper.puts "Ignoring XDCC request from '#{dcc.user.nick}' as it is not expected."
		end
	end

	def create_download_thread(dcc_, download_dir_ = "")
		download_dir_ = download_dir_ || ""
		Thread.new(dcc_, download_dir_) {
			|dcc, download_dir|
			Thread.current["dcc"] = dcc
			Thread.current["download_dir"] = download_dir

			save_path = "#{download_dir}#{dcc.filename}"
			Thread.current["file"] = save_path

			t = File.open("#{save_path}", "w")
			dcc.accept(t)
			@@helper.puts "Download finished."
			t.close
		}
	end

	def create_progress_thread(download_thread)
		Thread.new(download_thread) {
			|dl_thread|

			sleep 2
			dcc = dl_thread["dcc"]
			file = dl_thread["file"]

			total_size = dcc.size || 0
			size = 0

			Thread.current["total_size"] = total_size

			while (dl_thread.alive?)
				sleep 1 # limit progress check to once/2sec

				new_size = File.size(file)
				Thread.current["speed"] =  new_size - size
				Thread.current["progress"] = (total_size != 0 ? ((new_size.to_f/total_size.to_f)*100).to_i : 0)
				Thread.current["size"] = new_size

				size = new_size
			end
		}
	end

	def download
		if (@download && @download[:progress_thread]["total_size"])
			{
				:filename => @download[:filename],
				:downloading => @download[:download_thread].alive?,
				:progress => @download[:progress_thread]["progress"] || 0,
				:speed => @download[:progress_thread]["speed"],
				:size => @download[:progress_thread]["size"],
				:total_size => @download[:progress_thread]["total_size"]
			}
		end
	end
end

begin
	xdcc = XDCC.new(@@server, @@channel_name)
	xdcc.handler.download_folder = @@download_folder
	xdcc.handler.start_download(@@bot_name, @@file_number)

	while (xdcc.bot_thread.alive? && (xdcc.handler.download.nil? || xdcc.handler.download[:downloading]))
		sleep 1

		download = xdcc.handler.download
		if (download)
			@@helper.puts "#{download[:filename]}: #{Helper.human_size(download[:size])}/#{Helper.human_size(download[:total_size])} (#{download[:progress]}%) - #{Helper.human_size(download[:speed])}/s"
		end
	end

	@@helper.puts "Finished download. Quitting..."
	xdcc.bot.quit

	@@helper.restore_output
rescue Interrupt
	@@helper.restore_output
	puts "User cancelled download. Quitting..."
rescue Exception => e
	@@helper.restore_output
	raise e
end