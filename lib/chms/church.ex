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

    resource Chms.Church.Contributions do
      define :create_contribution, action: :create
      define :list_contributions, action: :read
      define :update_contribution, action: :update
      define :destroy_contribution, action: :destroy
      define :get_contribution_by_id, action: :read, get_by: [:id]
    end

    resource Chms.Church.MinistryFunds do
      define :create_ministry_fund, action: :create
      define :list_ministry_funds, action: :read
      define :update_ministry_fund, action: :update
      define :destroy_ministry_fund, action: :destroy
      define :get_ministry_fund_by_id, action: :read, get_by: [:id]
    end
  end
end
