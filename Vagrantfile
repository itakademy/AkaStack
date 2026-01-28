# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  ENV_FILE = File.join(__dir__, "project.env")

  if File.exist?(ENV_FILE)
    File.readlines(ENV_FILE).each do |line|
      next if line.strip.empty? || line.start_with?("#")
      key, value = line.strip.split("=", 2)
      ENV[key] ||= value
    end
  else
    abort "❌ project.env not found"
  end

  RANDOM_SUFFIX = rand(1000..9999)
  VM_NAME       = #{ENV.fetch("PROJECT_NAME")}-#{ENV.fetch("RANDOM_SUFFIX")}

  # ================================
  # Base box (Parallels)
  # ================================
  config.vm.provider "parallels" do |p|
    p.cpus  = ENV.fetch("VM_CPUS").to_i
    p.memory = ENV.fetch("VM_MEMORY").to_i
    p.name = VM_NAME
  end

  config.vm.box = ENV.fetch("VM_BASE")
  config.vm.box_version = ENV.fetch("VM_BASE_VERSION")

  # ================================
  # VM identity & network
  # ================================
  config.vm.hostname = VM_NAME

  config.vm.network "private_network", ip: ENV.fetch("VM_IP")

  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = false

  domain = ENV.fetch('PROJECT_DOMAIN')

  config.hostmanager.aliases = [
    "www.#{domain}",
    "back.#{domain}",
    "redis.#{domain}",
    "mail.#{domain}",
    "mongo.#{domain}",
    "swagger.#{domain}",
    domain
  ]

  # ================================
  # Synced folders
  # ================================
  config.vm.synced_folder "./", "/vagrant", disabled: true
  config.vm.synced_folder "./", "/var/www/project", owner: "vagrant", group: "www-data"

  # ================================
  # Provisioning
  # ================================
  config.vm.provision "shell",
    path: "install/provision.sh",
    privileged: true,
    env: {
      "VM_IP"             => ENV.fetch("VM_IP"),
      "PROJECT_NAME"      => ENV.fetch("PROJECT_NAME"),
      "PROJECT_DOMAIN"    => ENV.fetch("PROJECT_DOMAIN"),
      "MYSQL_HOST"        => ENV.fetch("MYSQL_HOST"),
      "MYSQL_PORT"        => ENV.fetch("MYSQL_PORT"),
      "MYSQL_ROOT_PASSWORD"  => ENV.fetch("MYSQL_ROOT_PASSWORD"),
      "MEMCACHED_HOST"    => ENV.fetch("MEMCACHED_HOST"),
      "REDIS_CLIENT"      => ENV.fetch("REDIS_CLIENT"),
      "REDIS_HOST"        => ENV.fetch("REDIS_HOST"),
      "REDIS_PASSWORD"    => ENV.fetch("REDIS_PASSWORD"),
      "REDIS_PORT"        => ENV.fetch("REDIS_PORT"),
      "BCRYPT_ROUNDS"     => ENV.fetch("BCRYPT_ROUNDS"),
      "MONGODB_VERSION"   => ENV.fetch("MONGODB_VERSION")
    }

  # ================================
  # Debug (optionnel)
  # ================================

  puts "▶ #{ENV.fetch("PROJECT_NAME")}"
  puts "▶ VM #{VM_NAME} - #{ENV.fetch("VM_BASE_VERSION")}"
  puts "▶ IP=#{ENV.fetch("VM_IP")} | CPU=#{ENV.fetch("VM_CPUS")} | RAM=#{ENV.fetch("VM_MEMORY")}MB"
end


