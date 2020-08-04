# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/container'
require 'java_buildpack/util/java_main_utils'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for applications running
    # JBoss applications.
    class WildflyCustom < JavaBuildpack::Component::BaseComponent
      include JavaBuildpack::Util

      def detect
        wildfly_custom_yml.exist? ? "#{self.class.to_s.dash_case}" : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        install_wildfly
        copy_deployments
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.environment_variables.add_environment_variable 'JAVA_OPTS', '$JAVA_OPTS'
        @droplet.java_opts
          .add_system_property('jboss.http.port', '$PORT')
          .add_system_property('java.net.preferIPv4Stack', true)
          .add_system_property('java.net.preferIPv4Addresses', true)

        [
          @droplet.environment_variables.as_env_vars,
          @droplet.java_home.as_env_var,
          'exec',
          "$PWD/#{(@droplet.sandbox + 'bin/standalone.sh').relative_path_from(@droplet.root)}",
          '-b',
          '0.0.0.0'
        ].compact.join(' ')
      end

      private

      def install_wildfly
        config = YAML.load_file(wildfly_custom_yml)
        uri    = config['archive']
        download_archive(uri) do |file|
          extract_archive(file, @droplet.sandbox)
        end
      end

      def download_archive(uri)
        download_start_time = Time.now
        print "#{'----->'.red.bold} Downloading custom Wildfly archive from #{uri.sanitize_uri} "

        JavaBuildpack::Util::Cache::CacheFactory.create.get(uri) do |file, downloaded|
          if downloaded
            puts "(#{(Time.now - download_start_time).duration})".green.italic
          else
            puts '(found in cache)'.green.italic
          end
          yield file
        end
      end

      def extract_archive(file, target_directory)
        # top level is stripped
        Dir.mktmpdir do |root|
          shell "unzip -qq #{file.path} -d #{root} 2>&1"

          FileUtils.mkdir_p target_directory.parent
          FileUtils.mv Pathname.new(root).children.first, target_directory
        end
      end

      def copy_deployments
        source_dir = @application.root + 'deployments'
        target_dir = @droplet.sandbox + 'standalone/deployments'
        FileUtils.mkdir_p target_dir
        source_dir.children.each { |child| FileUtils.cp_r child, target_dir }
      end

      def wildfly_custom_yml
        @application.root + 'wildfly-custom.yml'
      end

    end

  end
end
