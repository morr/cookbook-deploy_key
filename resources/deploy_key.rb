provides :deploy_key

property :service, %w(gitlab github bitbucket), default: 'github'
property :label, String, name_property: true
property :path, String, required: true
property :deploy_key_label, [String, NilClass], default: nil

# For OAuth: { token: token }
# For user/pass: { user: user, password: password }
property :credentials, Hash, required: true

# should be in the format: username/repo_slug (e.g.: cassianoleal/cookbook-deploy_key)
# or an integer for GitLab (e.g.: 4)
property :repo, [String, Integer], required: true, regex: /(\w+\/\w+|\d+)/

property :owner, String, default: 'root'
property :group, String, default: 'root'

property :mode, default: 00600

property :api_url, [String, NilClass], default: nil

# Client certificate support
property :client_cert, [String, NilClass], default: nil
property :client_key, [String, NilClass], default: nil

action_class do
  def load_service
    case new_resource.service
    when 'github'
      Chef::Resource.send(:include, DeployKeyCookbook::HelpersGithub)
      Chef::Provider.send(:include, DeployKeyCookbook::HelpersGithub)
    when 'gitlab'
      Chef::Resource.send(:include, DeployKeyCookbook::HelpersGitlab)
      Chef::Provider.send(:include, DeployKeyCookbook::HelpersGitlab)
    when 'bitbucket'
      Chef::Resource.send(:include, DeployKeyCookbook::HelpersBitbucket)
      Chef::Provider.send(:include, DeployKeyCookbook::HelpersBitbucket)
    end
  end
end

action :add do
  load_service
  new_resource.run_action(:create)

  pubkey = ::File.read("#{new_resource.path}/#{new_resource.label}.pub")
  if get_key(pubkey)
    Chef::Log.info("Deploy key #{new_resource.label} already added - nothing to do.")
  else
    converge_by("Register #{new_resource}") do
      label = new_resource.deploy_key_label.nil? ? new_resource.label : new_resource.deploy_key_label

      add_key(label, pubkey)
    end
  end
end

action :create do
  load_service
  if ::File.exist?("#{new_resource.path}/#{new_resource.label}") && ::File.exist?("#{new_resource.path}/#{new_resource.label}.pub")
    Chef::Log.info("Key #{new_resource.path}/#{new_resource.label} already exists - nothing to do.")
  else
    converge_by("Generate #{new_resource}") do
      directory new_resource.path do
        owner new_resource.owner
        group new_resource.group
        mode '0755'
        recursive true
        action :create
      end
      execute "Generate ssh key for #{new_resource.label}" do
        cwd new_resource.path
        creates new_resource.label
        command "ssh-keygen -t rsa -q -C '' -f '#{new_resource.path}/#{new_resource.label}' -P \"\""
      end
    end
  end

  file "#{new_resource.path}/#{new_resource.label}" do
    owner new_resource.owner
    group new_resource.group
    mode new_resource.mode
  end

  file "#{new_resource.path}/#{new_resource.label}.pub" do
    owner new_resource.owner
    group new_resource.group
    mode new_resource.mode
  end
end

action :delete do
  load_service
  key = "#{new_resource.path}/#{new_resource.label}"

  [key, "#{key}.pub"].each do |f|
    file f do
      action :delete
    end
  end
end

action :remove do
  load_service
  pubkey = ::File.read("#{new_resource.path}/#{new_resource.label}.pub")
  if get_key(pubkey)
    converge_by("De-register #{new_resource}") do
      remove_key(pubkey)
    end
  else
    Chef::Log.info("Deploy key #{new_resource} not present - nothing to do.")
  end
end
