defmodule Churchapp.Accounts do
  use Ash.Domain, otp_app: :churchapp, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Churchapp.Accounts.Token

    resource Churchapp.Accounts.User do
      define :list_users, action: :read
      define :get_user_by_id, action: :read, get_by: [:id]
      define :update_user_role_and_permissions, action: :update_role_and_permissions
      define :delete_user, action: :destroy
    end
  end
end
