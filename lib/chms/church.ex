defmodule Chms.Church do
  use Ash.Domain,
    otp_app: :churchapp,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Chms.Church.Congregants do
      define :create_congregant, action: :create
      define :list_congregants, action: :read
      define :update_congregant, action: :update
      define :destroy_congregant, action: :destroy
      define :get_congregant_by_id, action: :read, get_by: [:id]
      define :get_congregant_by_member_id, action: :read, get_by: [:member_id]
    end
  end
end
