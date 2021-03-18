# return 'Error: specify a folder as an argument' unless ARGV.first

# directory = ARGV.first
# wavs = Dir["#{directory}/*"]
wavs = ['tense.wav', 'relaxed.wav']
seconds = 0.1

wavs.each do |wav|
  name = wav.delete_suffix('.wav')

  # delete old wavs and pngs
  `rm dataset/#{name}/*`

  # cut #{name}.wav in #{seconds} long wavs
  `sox #{wav} dataset/#{name}/part.wav trim 0 #{seconds} : newfile : restart`

  # check volume for each wav
  puts 'checking volume for each wav'
  files = Dir["dataset/#{name}/*.wav"].map do |filename|
    [
      filename,
      (`sox #{filename} -n stat 2>&1 | grep "Maximum amplitude"`.scan(/\d+\.\d+/).flatten.first.to_f * 1000).to_i
    ]
  end

  # delete wavs that are not loud enough
  puts 'deleting wavs that are not loud enough'
  files.each do |filename, volume|
    `rm #{filename}` if volume < 50
  end

  # normalize all wav files
  puts 'normalising all wav files'
  Dir["dataset/#{name}/*.wav"].each_with_index do |filename, index|
    puts index if index % 10 == 0
    `sox --norm=-3 #{filename} normalised-#{filename}`
  end

  # generate spectrograms for all wav files
  puts 'generating spectrograms for all wav files'
  Dir["normalised-dataset/#{name}/*.wav"].each do |filename|
    `sox #{filename} -n spectrogram -m -o #{filename.sub(".wav", ".png")}`
  end

  # crop png files
  puts 'cropping images'
  Dir["normalised-dataset/#{name}/*.png"].each_with_index do |filename, index|
    puts index if index % 10 == 0
    `mogrify -crop 550x138+58+150 #{filename}`
  end

  # delete the intermediate wav files
  puts 'cleaning up'
  `rm dataset/#{name}/*.wav`
  `rm normalised-dataset/#{name}/*.wav`
end
