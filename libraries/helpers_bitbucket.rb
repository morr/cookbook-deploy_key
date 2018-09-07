module DeployKeyCookbook
  module HelpersBitbucket
    def url(path = '')
      URI.parse("https://bitbucket.org/api/1.0/repositories/#{new_resource.repo}/deploy-keys#{path}")
    end

    def add_token(request)
      request.add_field 'Authorization', "Bearer #{new_resource.credentials[:token]}"
      request
    end

    def provider_specific_key_label
      :label
    end

    def retrieved_key_id
      'pk'
    end
  end
end
