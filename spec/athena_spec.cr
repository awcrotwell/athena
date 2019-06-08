require "./spec_helper_methods"
require "../src/athena"

COMMANDS = <<-COMMANDS
Registered Commands:
\tathena
\t\tathena:generate:config_file - Generates the default config file for Athena\n
COMMANDS

EXPLAIN = <<-EXPLAIN
Command
\tathena:generate:config_file - Generates the default config file for Athena
Usage
\t./YOUR_BINARY -c athena:generate:config_file [arguments]
Arguments
\toverride : Bool = false
\tpath : String = "athena.yml"\n
EXPLAIN

DEFAULT_CONFIG_YAML = <<-YAML
---
environments:
  development: &development
    routing:
      cors:
        enabled: false
        strategy: blacklist
        defaults: &defaults
          allow_origin: https://yourdomain.com
          expose_headers: []
          max_age: 0
          allow_credentials: false
          allow_methods: []
          allow_headers: []
        groups: {}
  test: &test
    <<: *development
  production: &production
    <<: *development\n
YAML

Spec.before_each { Crylog::Registry.clear }
Spec.before_each { ENV["ATHENA_ENV"] = "test" }

puts
puts
puts "Running Athena Specs"
puts

describe Athena do
  describe "binary" do
    describe "--list -l" do
      it "should list available commands" do
        run_binary(args: ["-l"]) do |output|
          output.should eq COMMANDS
        end
      end
    end

    describe "--explain -e" do
      it "should print the help" do
        run_binary(args: ["-e", "athena:generate:config_file"]) do |output|
          output.should eq EXPLAIN
        end
      end
    end

    describe Athena::Commands do
      describe "athena:generate:config_file" do
        describe "when the config file already exists" do
          it "should not recreate the file" do
            created = File.info "athena.yml"
            run_binary(args: ["-c", "athena:generate:config_file"]) do |_output|
              created.modification_time.should eq File.info("athena.yml").modification_time
            end
          end
        end

        describe "when using the override flag" do
          it "should recreate the file" do
            original = File.info "athena.yml"
            run_binary(args: ["-c", "athena:generate:config_file", "--override=true"]) do |_output|
              (original.modification_time < File.info("athena.yml").modification_time).should be_true
            end
          end
        end

        describe "when using the path flag" do
          it "should create the file at the given location" do
            File.exists?("#{Dir.tempdir}/athena.yml").should be_false
            run_binary(args: ["-c", "athena:generate:config_file", "--path=#{Dir.tempdir}/athena.yml"]) do |_output|
              File.exists?("#{Dir.tempdir}/athena.yml").should be_true
              File.delete("#{Dir.tempdir}/athena.yml")
            end
          end
        end

        it "should generate the correct yaml" do
          Athena::Config::Environments.new.to_yaml.should eq DEFAULT_CONFIG_YAML
        end
      end
    end
  end

  describe ".config" do
    describe "with the default path" do
      it "should return the standard object" do
        ENV["ATHENA_ENV"] = "test"
        config = Athena.config
        config.routing.cors.enabled.should be_false
        config.routing.cors.groups.empty?.should be_true
        config.routing.cors.defaults.allow_origin.should eq "https://yourdomain.com"
        config.routing.cors.strategy.should eq "blacklist"
      end
    end

    describe "with a provided path" do
      it "should return the standard object" do
        ENV["ATHENA_ENV"] = "test"
        ENV["ATHENA_CONFIG_PATH"] = "spec/routing/athena.yml"
        config = Athena.config
        config.routing.cors.enabled.should be_true
        config.routing.cors.groups.has_key?("class_overload").should be_true
        config.routing.cors.groups.has_key?("action_overload").should be_true
        config.routing.cors.defaults.allow_origin.should eq "DEFAULT_DOMAIN"
        config.routing.cors.strategy.should eq "blacklist"
      end
    end
  end
end