require 'fileutils'
require 'rb-inotify'
require 'pry'
require 'open3'

wav_queue 					= []
results							= []
spectrogram_queue 	= []
tense_percentage		= 50
log_manager					= Mutex.new
wav_queue_manager 	= Mutex.new
spectrogram_queue_manager = Mutex.new

folders = ["recordings", "processing", "spectrograms"]
folders.each do |dir|
	Dir.mkdir(dir) unless Dir.exist?(dir)
	FileUtils.rm Dir.glob("#{dir}/*")
end

recording_thread = Thread.new {
	sleep 2
	$live_recording = spawn("rec recordings/%n.wav -q trim 0 0.1 : newfile : restart")
}

wav_queue_thread = Thread.new {
	notifier = INotify::Notifier.new
	notifier.watch("./recordings", :create) do |event|
		filename = event.absolute_name.delete_prefix("./recordings/")

    # puts "File created: #{filename}"
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
	sleep 2.2
	loop do
		sleep 0.05
		wav_queue_manager.synchronize {
			if wav_queue.length > 15
				while wav_queue.length > 2
					split_file = wav_queue.pop
					timestamp  = Time.now.strftime("%Y-%m-%d %k:%M:%S.%L")

					# puts "Wav queue full: dropping #{split_file}"

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

				amplitude = `sox processing/#{split_file} -n stat 2>&1 | grep "Maximum amplitude"`.scan(/\d+\.\d+/).flatten.first.to_f * 1000.to_i
		  	# puts amplitude

		 		# Remove silent splits
  	  	if amplitude < 5
  	  		# puts "Low amplitude (#{amplitude}): removing #{normalized_split}"
  		  	FileUtils.rm "processing/#{split_file}"
  		  else
  		  	 # Normalize remaining splits
			  	`sox --norm=-3 processing/#{split_file} processing/#{normalized_split}`
			  	FileUtils.rm "processing/#{split_file}"

			  	# Convert splits to spectrograms
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

at_exit do
	`kill #{$live_recording}`
end

cmd = "python3 evaluator.py"
Open3.popen3(cmd) do |stdin, stdout, _stderr, wait_thr|
	pid = wait_thr.pid
	stdin.sync = true
	loop do
		sleep 0.05
		spectrogram_queue_manager.synchronize {
			if spectrogram_queue.length > 10
				while spectrogram_queue.length > 2
					spectrogram = spectrogram_queue.pop

					# puts "Spectrogram queue full: dropping #{spectrogram}"
					timestamp = Time.now.strftime("%Y-%m-%d %k:%M:%S.%L")
		    	log_manager.synchronize {
						File.open('log.txt', 'a') { |f|
						  f.puts "[#{timestamp}] Spectrogram queue full: dropping #{spectrogram}"
						}
					}
					FileUtils.rm "spectrograms/#{spectrogram}"	
				end
			elsif spectrogram_queue.length > 0
				# evt spectrogram_path en evaluation gekoppeld houden en opslaan voor debuggen?
				spectrogram      = spectrogram_queue.pop
				spectrogram_path = "spectrograms/#{spectrogram}"

				stdin.puts spectrogram_path

				evaluator_output = stdout.gets.strip.split("\r").last.split(",")

				# p "#{spectrogram}: #{evaluator_output}"

				result = evaluator_output[0]
				confidence_relaxed = evaluator_output[1].to_f
				confidence_tense	 = evaluator_output[2].to_f 

				FileUtils.rm "spectrograms/#{spectrogram}"

				if result == "relaxed" && confidence_relaxed > 0.85 && confidence_tense < 0.2
					results << "relaxed"
					puts "Confident relaxed spectrogram found: #{spectrogram} - relaxed: #{confidence_relaxed}, tense: #{confidence_tense}"
				elsif result == "tense" && confidence_tense > 0.85 && confidence_relaxed < 0.2
					results << "tense"
					puts "Confident tense spectrogram found: #{spectrogram} - tense #{confidence_tense}, relaxed: #{confidence_relaxed}"
				end

				if results.length >= 100
					if results.length > 100
						results.shift(results.length - 10)
					end

					total_results = results.length.to_f
					tense_results = results.count("tense")
					final_result  = (tense_results / total_results).truncate(2) * 100

					puts "final result = #{final_result}"

					# TODO: implement xmessage pop-up
					if final_result >= tense_percentage
						puts "Omg straining!"
					else
						puts "No straining!"
					end
				end
			end
		}
	end
	exit_status = wait_thr.value
end

wav_processing_thread.join
wav_queue_thread.join
recording_thread.join
