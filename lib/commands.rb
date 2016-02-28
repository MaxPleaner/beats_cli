require 'active_support/inflector'
require 'byebug'
require 'securerandom'
require 'yaml'

BASE_TEMPO = 360

class OddTimePhrase 
  attr_accessor :odd_time_sequence, :min, :max
  def self.random
    time_pairs = [
      [3, 32], [5, 32], [7, 32], [9, 32]
    ]
    return self.new(*time_pairs.sample)
  end
  def initialize(time1, time2)
    @max, @min = [time1, time2].max, [time1, time2].min
    @odd_time_sequence = [
      Array.new((max / min), min), # play min N times
      (max % min)                  # the leftover amount 
    ].flatten
  end
end

class Commands
  def initialize(options={})
    # make sure this method accepts a hash argument, which is passed from OptionParser
    puts "try 'help'".yellow
  end
  def hello_world(msg="")
    # a sample event, call it with hello_world
    puts "hello_world #{msg}"
    return { foo: :bar }
  end

  def odd_time(options={})
    tempo = options[:tempo] || BASE_TEMPO
    if options[:beat_counts]
      # a time pair i.e. [5, 32]
      sequence = OddTimePhrase.new(*options[:beat_counts])
    else
      sequence = OddTimePhrase.random # uses random time pair
    end
    min, max = sequence.min, sequence.max
    puts "#{"odd time sequence".blue}: #{sequence.odd_time_sequence.join(", ").green}"
    count_frequencies = {}
    # write some files
    output_base = "./output_base.wav"
    `rm #{output_base}`
    `touch #{output_base}`
    (options[:repetitions] || 4).times do
      sequence.odd_time_sequence.each do |beats_count|
        sleep 1
        count_frequencies[beats_count] ||= 0
        count_frequencies[beats_count] += 1
        beat_api = BeatsAPI.new(tempo: tempo || BASE_TEMPO)
        yml_filename = "./output/#{Time.now.to_i}.yml"
        wav_filename = yml_filename.gsub("yml", "wav")
        return "err" unless beat_api.write_rhythm(beats: beats_count, filename: yml_filename)
        return "err" unless beat_api.write_melody(beats: beats_count, filename: yml_filename)
        puts "writing #{beats_count} instructions to #{yml_filename}"
        return "err" unless beat_api.save(filename: yml_filename)
        # compile the file to output/output_append.wav
        if count_frequencies[beats_count] > 1
          puts "copying existing wav file"
          `cp #{Dir.glob("./output/*wav").sort[-1]} #{wav_filename}`
        else
          puts "compiling #{wav_filename}"
          `beats #{yml_filename} #{wav_filename}`
        end
        `rm #{yml_filename}`
      end
    end
    `sox #{Dir.glob("./output/*wav").sort.join(" ")} #{output_base}`
    `rm ./output/*wav`
    `totem #{output_base}`
  end

  def clear_output
    `rm -rf ./output/*`
  end

end

class BeatsAPI
  attr_reader :tempo, :current_song
  def initialize(options={})
    @tempo = options[:tempo] || BASE_TEMPO
    @current_song = {}
  end

  def song_template(options={})
    # a 'melody' or 'rhythm' is an object i.e. { snare: "x..x..x..x.." }
    tempo, melody, rhythm = options.values_at(:tempo, :melody, :rhythm)
    return nil unless [tempo, melody, rhythm].all?
    base_structure = {
      "Song" => {
        "Tempo" => tempo,
        "Flow" => [
          { "Verse" => 'x1' },
        ],
        "Kit" => [
          { "bass" => "../casio_instruments/bass2.wav" },
          { "snare" => "../casio_instruments/snare2.wav" },
          { "hihat" => "../casio_instruments/hh_open.wav" },
          { "cowbell" => "../casio_instruments/rim.wav" },
          { "deep" => "../casio_instruments/tom4.wav" },
        ]
      },
      "Verse" => [melody, rhythm]
    }
    YAML.dump(base_structure)
  end
  def write_rhythm(options={})
    beats, filename = options.values_at(:beats, :filename)
    return nil unless [beats, filename].all?
    rhythm = rhythm_instruments.sample
    phrase = musical_phrases[beats]
    @current_song[:rhythm] = { rhythm => phrase }
  end
  def write_melody(options={})
    beats, filename = options.values_at(:beats, :filename)
    return nil unless [beats, filename].all?
    melody = melody_instruments.sample
    phrase = musical_phrases[beats]
    @current_song[:melody] = { melody => phrase }
  end
  def save(options={})
    filename = options[:filename]
    return nil unless filename
    template = song_template({
      tempo: self.tempo,
      melody: @current_song[:melody],
      rhythm: @current_song[:rhythm]
    })
    File.open(filename, 'w') { |file| file.write(template) }
  end
  def rhythm_instruments
    ["bass", "deep", "snare", "hihat", "cowbell"]
  end
  def melody_instruments
    ["bass", "deep", "snare", "hihat", "cowbell"]
  end
  def musical_phrases
    # make sure to use capital X
    {
      2 => "XX..",
      3 => "XX.XX.",
      4 => "XXXXX...",
      5 => "XXXX..XX..",
      6 => "XXX..XXX..XX",
      7 => "XX..XX..XX..XX.",
      8 => "XX..XXX..XX...XX",
      9 => "X.XX.XX.XX.XX.XX..",
    }
  end
end