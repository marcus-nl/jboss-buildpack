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
require 'java_buildpack/container/galleon'

describe JavaBuildpack::Container::Galleon do
  include_context 'with component help'

  it 'detects provision.xml',
     app_fixture: 'container_galleon' do

    expect(component.detect).to include("galleon=#{version}")
  end

  it 'does not detect when provision.xml is absent',
     app_fixture: 'container_main' do

    expect(component.detect).to be_nil
  end

  it 'extracts and invokes Galleon',
     log_level:     'DEBUG',
     no_cleanup:     true,
     app_fixture:   'container_galleon',
     cache_fixture: 'stub-galleon.zip' do

    allow(component).to receive(:shell).with(start_with('unzip -qq')).and_call_original
    allow(component).to receive(:shell).with(start_with("JAVA_HOME=#{java_home.root} exec #{sandbox}/bin/galleon.sh provision")).and_call_original

    component.compile

    expect(sandbox + 'bin/galleon.sh').to exist
    expect(sandbox + 'wildfly/standalone/deployments/ROOT.war/index.html').to exist
    expect(sandbox + 'wildfly/standalone/deployments/ROOT.war.dodeploy').to exist
  end

  it 'returns command',
     app_fixture: 'container_galleon' do

    expect(component.release).to eq("test-var-2 test-var-1 JAVA_OPTS=$JAVA_OPTS #{java_home.as_env_var} exec " \
                                        '$PWD/.java-buildpack/galleon/wildfly/bin/standalone.sh -b 0.0.0.0')
  end

end
