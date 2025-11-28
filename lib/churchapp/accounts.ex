defmodule Churchapp.Accounts do
  use Ash.Domain, otp_app: :churchapp, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Churchapp.Accounts.Token
    resource Churchapp.Accounts.User
  end
end
