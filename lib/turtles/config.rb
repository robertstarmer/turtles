module Turtles
  CONFIG_PATH = File.expand_path("~/.turtles")
  DEFAULT_CONFIG = {
    "cloud" => { :provider => 'AWS', :region => 'us-west-2' }
  }

  def self.config
    self.load_config if @config.nil?
    @config
  end
  
  def self.cloud
    self.setup_cloud if @cloud.nil?
    @cloud
  end
  attr_writer :cloud

  def self.setup_cloud
    @cloud = Fog::Compute.new(self.config['cloud'])
  end

  def self.load_config
    return unless @config.nil?
    File.open(CONFIG_PATH, 'r') do |f|
      @config = YAML::load(f.read())
    end
  rescue Errno::ENOENT
    @config = DEFAULT_CONFIG
    self.save_config()
  end

  def self.save_config
    File.open(CONFIG_PATH, 'w') do |f|
      f.write(YAML::dump(@config))
    end
  end 
 
end

