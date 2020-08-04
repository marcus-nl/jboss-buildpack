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

require 'spec_helper'
require 'component_helper'
require 'java_buildpack/container/wildfly_custom'

describe JavaBuildpack::Container::WildflyCustom do
  include_context 'with component help'

  it 'detects wildfly_custom.yml',
     app_fixture: 'container_wildfly_custom' do

    expect(component.detect).to include('wildfly-custom')
  end

  it 'does not detect when wildfly_custom.yml is absent',
     app_fixture: 'container_main' do

    expect(component.detect).to be_nil
  end

  it 'downloads and extracts Wildfly',
     log_level:     'DEBUG',
     no_cleanup:     true,
     app_fixture:   'container_wildfly_custom',
     cache_fixture: 'stub-wildfly-custom.zip' do

    allow(component).to receive(:shell).with(start_with('unzip -qq')).and_call_original

    component.compile

    expect(sandbox + 'bin/standalone.sh').to exist
  end

  it 'returns command',
     app_fixture: 'container_wildfly_custom' do

    expect(component.release).to eq("test-var-2 test-var-1 JAVA_OPTS=$JAVA_OPTS #{java_home.as_env_var} exec " \
                                        '$PWD/.java-buildpack/wildfly_custom/bin/standalone.sh -b 0.0.0.0')
  end

end
