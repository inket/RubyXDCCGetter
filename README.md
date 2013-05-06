###Ruby XDCC getter (name subject to change)

###### Required
- Ruby >=1.9.1
- cinch (`gem install cinch`)

###### Usage

`ruby xdcc.rb <server> <bot_name> <file_number> [-c <channel_name>] [-d <download_folder>] [-o <bot_log_file>]`


###### Example
> `ruby xdcc.rb irc.rizon.net Cerebrate 321 -d '~/Downloads/' -o output.log -c horriblesubs`<br><br>
> Your parameters:<br>
> \*Server: irc.rizon.net<br>
> \*Bot name: Cerebrate<br>
> \*Requested file: 321<br>
> \*Join channel: #horriblesubs<br>
> \*Download folder: /Users/inket/Downloads/<br>
> \*Bot log file: /Users/inket/Desktop/output.log<br>
> 
> 
> Starting bot...<br>
> Connecting...<br>
> Connected.<br>
> Asking Cerebrate for download 321...<br>
> Received response:<br>
> \*File: MPC-HC.1.6.7.7114.x86.7z<br>
> *Size: 6.24MB<br>
> 
> Starting download...<br>
> Download started.<br>
> MPC-HC.1.6.7.7114.x86.7z: 0/6.24MB (0%) - 0/s<br>
> MPC-HC.1.6.7.7114.x86.7z: 2.02MB/6.24MB (32%) - 2.02MB/s<br>
> MPC-HC.1.6.7.7114.x86.7z: 2.94MB/6.24MB (47%) - 936KB/s<br>
> MPC-HC.1.6.7.7114.x86.7z: 3.76MB/6.24MB (60%) - 845KB/s<br>
> MPC-HC.1.6.7.7114.x86.7z: 4.58MB/6.24MB (73%) - 834KB/s<br>
> MPC-HC.1.6.7.7114.x86.7z: 5.40MB/6.24MB (86%) - 837KB/s<br>
> Download finished.<br>
> MPC-HC.1.6.7.7114.x86.7z: 6.22MB/6.24MB (99%) - 837KB/s<br>
> Finished download. Quitting...<br>