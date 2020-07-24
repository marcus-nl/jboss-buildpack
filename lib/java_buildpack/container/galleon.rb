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
    class Galleon < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip
        provision_wildfly
        copy_application
        copy_additional_libraries
        create_dodeploy
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
          "$PWD/#{(wildfly_dir + 'bin/standalone.sh').relative_path_from(@droplet.root)}",
          '-b',
          '0.0.0.0'
        ].compact.join(' ')
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        provision_xml.exist? && !JavaBuildpack::Util::JavaMainUtils.main_class(@application)
      end

      private

      def provision_wildfly
        galleon_sh = @droplet.sandbox + 'bin/galleon.sh'
        cmd = [
          "JAVA_HOME=#{@droplet.java_home.root}",
          'exec',
          galleon_sh,
          'provision',
          provision_xml,
          "--dir=#{wildfly_dir}"
        ].flatten.compact.join(' ')
        shell cmd
      end

      def copy_application
        FileUtils.mkdir_p root_dir
        @application.root.children.each { |child| FileUtils.cp_r child, root_dir }
      end

      def copy_additional_libraries
        web_inf_lib = root_dir + 'WEB-INF/lib'
        FileUtils.mkdir_p web_inf_lib
        @droplet.additional_libraries.each { |additional_library| FileUtils.cp_r additional_library, web_inf_lib }
      end

      def create_dodeploy
        FileUtils.touch(webapps_dir + 'ROOT.war.dodeploy')
      end

      def root_dir
        webapps_dir + 'ROOT.war'
      end

      def webapps_dir
        wildfly_dir + 'standalone/deployments'
      end

      def wildfly_dir
        @droplet.sandbox + 'wildfly'
      end

      def provision_xml
        @application.root + 'WEB-INF/provisioning.xml'
      end

    end

  end
end
