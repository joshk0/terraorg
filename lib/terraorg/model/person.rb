# Copyright 2019-2020 LiveRamp Holdings, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'faraday'

# The following statuses are considered ACTIVE by terraorg, which allow PRs to continue and be merged. 
# A DEACTIVATED account status needs to be removed from the repository before merging PRs

class Person
  ACTIVE_USER_STATUSES = ['ACTIVE', 'PROVISIONED', 'PASSWORD_EXPIRED', 'SUSPENDED', 'LOCKED_OUT'].freeze

  attr_accessor :id, :name, :okta_id, :email, :status

  def initialize(uid, okta: nil, cached: nil)
    @id = uid

    if cached
      @name = cached.fetch('name')
      @okta_id = cached.fetch('okta_id')
      @email = cached.fetch('email')
      @status = cached.fetch('status')

      return
    elsif !okta
      # We could just be running in fmt mode, so lie about everything
      @name = "real name of #{@id}"
      @okta_id = "fake okta id for #{@id}"
      @email = "#{@id}@my.domain"
      @status = 'PROVISIONED'

      return
    end

    # Retrieve from okta
    tries = 1
    total_tries = 5

    begin
      o = okta.get_user(uid)
    rescue Faraday::ConnectionFailed => e
      if tries <= total_tries
        puts "looking up user #{uid}: #{e} (try #{tries}/#{total_tries})"
        tries += 1
        retry
      end
      raise
    end

    if tries > 1
      puts "looking up user #{uid}: success!"
    end

    # NOTE: allows users in states other than ACTIVE
    # if you want to check that, do it outside of here
    obj = o[0].to_hash
    @name = obj.fetch(:profile).fetch(:displayName)
    @okta_id = obj.fetch(:id)
    @email = obj.fetch(:profile).fetch(:email)
    @status = obj.fetch(:status)
  end

  def active?
    ACTIVE_USER_STATUSES.member?(@status)
  end

  def to_json(options = nil)
    {'id' => @id, 'name' => @name, 'okta_id' => @okta_id, 'email' => @email, 'status' => @status}.to_json
  end
end
