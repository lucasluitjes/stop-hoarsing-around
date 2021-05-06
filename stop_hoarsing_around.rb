require 'fileutils'
require 'rb-inotify'
require 'pry'

# TODO: rechter reepje ook van spectrograms afhalen tijdens croppen?

wav_queue 					= []
spectrogram_queue 	= []
log_manager					= Mutex.new
wav_queue_manager 	= Mutex.new
spectrogram_queue_manager = Mutex.new

folders = ["recordings", "processing", "spectrograms"]
folders.each do |dir|
	Dir.mkdir(dir) unless Dir.exist?(dir)
	FileUtils.rm Dir.glob("#{dir}/*")
end

recording_thread = Thread.new {
	$live_recording = spawn("rec recordings/%n.wav -q trim 0 0.1 : newfile : restart")
}

wav_queue_thread = Thread.new {
	notifier = INotify::Notifier.new
	notifier.watch("./recordings", :create) do |event|
		filename = event.absolute_name.delete_prefix("./recordings/")

    puts "File created: #{filename}"
  	log_manager.synchronize {
  		timestamp = Time.now.strftime("%Y-%m-%d %k:%M:%S.%L")
  		File.open('log.txt', 'a') { |f|
  		  f.puts "[#{timestamp}] File created: #{filename}"
  		}
  	}

  	wav_queue_manager.synchronize {
	    wav_queue.unshift(filename)
  	}
	end
	notifier.run
}

wav_processing_thread = Thread.new {
	sleep 0.5
	loop do
		sleep 0.05
		wav_queue_manager.synchronize {
			if wav_queue.length > 15
				while wav_queue.length > 2
					split_file = wav_queue.pop
					timestamp  = Time.now.strftime("%Y-%m-%d %k:%M:%S.%L")

					puts "Wav queue full: dropping #{split_file}"

		    	log_manager.synchronize {
						File.open('log.txt', 'a') { |f|
						  f.puts "[#{timestamp}] Wav queue full: dropping #{split_file}"
						}
					}

					FileUtils.rm "recordings/#{split_file}"
				end

			elsif wav_queue.length > 0
				split_file			 = wav_queue.pop
				normalized_split = split_file.sub(".wav", "n.wav")
				spectrogram 		 = normalized_split.sub(".wav", ".png")

				FileUtils.mv "recordings/#{split_file}", "processing/"

			  # Normalize splits
		  	`sox --norm=-3 processing/#{split_file} processing/#{normalized_split}`
		  	FileUtils.rm "processing/#{split_file}"

		 		# Remove silent splits and convert remaining splits to spectrograms
		  	amplitude = `sox processing/#{normalized_split} -n stat 2>&1 | grep "Maximum amplitude"`.scan(/\d+\.\d+/).flatten.first.to_f * 1000.to_i
		  	if amplitude < 50
			  	FileUtils.rm "processing/#{normalized_split}"
			  else
			  	`sox processing/#{normalized_split} -n spectrogram -m -o spectrograms/#{spectrogram}`
			  	FileUtils.rm "processing/#{normalized_split}"
			  	
				  # Crop spectrograms and place them in a queue
					`mogrify -crop 550x138+58+150 spectrograms/#{spectrogram}`
					spectrogram_queue_manager.synchronize {
						spectrogram_queue.unshift(spectrogram)
					}
			  end
			end
		}
	end
}

spectrogram_processing_thread = Thread.new {
	loop do
		sleep 0.05
		spectrogram_queue_manager.synchronize {
			if spectrogram_queue.length > 10
				spectrogram = spectrogram_queue.pop

				puts "Spectrogram queue full: dropping #{spectrogram}"
				timestamp = Time.now.strftime("%Y-%m-%d %k:%M:%S.%L")
	    	log_manager.synchronize {
					File.open('log.txt', 'a') { |f|
					  f.puts "[#{timestamp}] Spectrogram queue full: dropping #{spectrogram}"
					}
				}
				FileUtils.rm "spectrograms/#{spectrogram}"	
			end
		}
	end
}

at_exit do
	`kill #{$live_recording}`
end

spectrogram_processing_thread.join
wav_processing_thread.join
wav_queue_thread.join
recording_thread.join
