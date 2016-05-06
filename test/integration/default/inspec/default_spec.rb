service_name = if %w(debian ubuntu).include?(os[:family])
  'apache2'
else
  'httpd'
end

control '01' do
  impact 0.7
  title 'Verify #{service_name} service'
  desc 'Ensures #{service_name} service is up and running'
  describe service(service_name) do
    it { should be_enabled }
    it { should be_installed }
    it { should be_running }
  end
end

describe port(80) do
  it { should be_listening }
end

describe command('curl http://localhost/index.html') do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /[Hello World]/ }
end