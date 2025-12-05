# Ministry Funds - Implementation Guide

This guide provides step-by-step instructions for implementing the Ministry Funds feature. Follow these steps in order for a smooth implementation.

## Prerequisites

- Review [`MINISTRY_FUNDS_SPEC.md`](MINISTRY_FUNDS_SPEC.md:1) for complete requirements
- Review [`MINISTRY_FUNDS_ARCHITECTURE.md`](MINISTRY_FUNDS_ARCHITECTURE.md:1) for system design
- Ensure you have access to the existing codebase patterns

## Implementation Steps

### Step 1: Create the Ash Resource

**File:** `lib/chms/church/ministry_funds.ex`

**Reference:** [`lib/chms/church/contributions.ex`](lib/chms/church/contributions.ex:1) for similar pattern

**Key Points:**
- Use `AshPostgres.DataLayer`
- Include `Ash.Policy.Authorizer`
- Define attributes: `ministry_name`, `transaction_type`, `amount`, `transaction_date`, `notes`
- Transaction type must be atom with constraint: `one_of: [:revenue, :expense]`
- Amount must be decimal with constraints: `precision: 10, scale: 2`
- Add authorization policies similar to contributions
- Include create, read, update, destroy actions

**Template:**
```elixir
defmodule Chms.Church.MinistryFunds do
  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "ministry_funds"
    repo Churchapp.Repo
  end

  # Actions, policies, attributes, etc.
end
```

---

### Step 2: Create Database Migration

**File:** `priv/repo/migrations/YYYYMMDDHHMMSS_add_ministry_funds.exs`

**Generate with:** `mix ash_postgres.generate_migrations --name add_ministry_funds`

**Expected Schema:**
```sql
CREATE TABLE ministry_funds (
  id UUID PRIMARY KEY,
  ministry_name VARCHAR NOT NULL,
  transaction_type VARCHAR NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  transaction_date TIMESTAMP NOT NULL,
  notes TEXT,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  
  CONSTRAINT ministry_funds_transaction_type_check 
    CHECK (transaction_type IN ('revenue', 'expense')),
  CONSTRAINT ministry_funds_amount_check 
    CHECK (amount >= 0)
);

CREATE INDEX idx_ministry_funds_ministry_name ON ministry_funds(ministry_name);
CREATE INDEX idx_ministry_funds_transaction_date ON ministry_funds(transaction_date);
CREATE INDEX idx_ministry_funds_transaction_type ON ministry_funds(transaction_type);
```

**Run:** `mix ecto.migrate`

---

### Step 3: Update Chms.Church Domain

**File:** [`lib/chms/church.ex`](lib/chms/church.ex:1)

**Add to resources block:**
```elixir
resource Chms.Church.MinistryFunds do
  define :create_ministry_fund, action: :create
  define :list_ministry_funds, action: :read
  define :update_ministry_fund, action: :update
  define :destroy_ministry_fund, action: :destroy
  define :get_ministry_fund_by_id, action: :read, get_by: [:id]
end
```

---

### Step 4: Update Ministries Module

**File:** [`lib/chms/church/ministries.ex`](lib/chms/church/ministries.ex:1)

**Changes:**
- Keep existing `@ministries` list as `@default_ministries`
- Add `all_ministries/0` function that queries database for custom ministries
- Add `ministry_options/0` that returns tuples for form options
- Keep existing validation functions

**Reference Pattern:** [`lib/chms/church/contribution_types.ex`](lib/chms/church/contribution_types.ex:1)

---

### Step 5: Create Ministry Selector Component

**File:** `lib/churchapp_web/components/ministry_selector.ex`

**Reference:** [`lib/churchapp_web/components/contribution_type_selector.ex`](lib/churchapp_web/components/contribution_type_selector.ex:1)

**Key Features:**
- LiveComponent with searchable dropdown
- Keyboard navigation (ArrowUp, ArrowDown, Enter, Escape)
- Filter ministries as user types
- Clear selection button
- Hidden input for form submission

**Props:**
- `field` - Form field
- `form` - Parent form
- `ministries` - List of ministry options

---

### Step 6: Create Index LiveView

**File:** `lib/churchapp_web/live/ministry_funds/index_live.ex`

**Reference:** [`lib/churchapp_web/live/contributions/index_live.ex`](lib/churchapp_web/live/contributions/index_live.ex:1)

**Features:**
- List all ministry fund transactions
- Search by ministry name, notes
- Filter by ministry, transaction type, date range, amount range
- Display balance per ministry (calculated in mount/handle_event)
- Bulk selection and deletion
- Pagination (10 per page)
- Summary statistics at top

**Key Assigns:**
```elixir
@ministry_funds - List of transactions
@ministry_balances - Map of ministry => balance
@search_query, @ministry_filter, @type_filter
@date_from, @date_to, @amount_min, @amount_max
@selected_ids, @show_delete_confirm
@page, @per_page, @total_count, @total_pages
```

**Balance Calculation Helper:**
```elixir
defp calculate_ministry_balances(transactions) do
  transactions
  |> Enum.group_by(& &1.ministry_name)
  |> Enum.map(fn {ministry, txns} ->
    revenues = txns
      |> Enum.filter(&(&1.transaction_type == :revenue))
      |> Enum.map(&Decimal.to_float(&1.amount))
      |> Enum.sum()
    
    expenses = txns
      |> Enum.filter(&(&1.transaction_type == :expense))
      |> Enum.map(&Decimal.to_float(&1.amount))
      |> Enum.sum()
    
    balance = Decimal.sub(
      Decimal.from_float(revenues),
      Decimal.from_float(expenses)
    )
    
    {ministry, balance}
  end)
  |> Map.new()
end
```

---

### Step 7: Create New LiveView

**File:** `lib/churchapp_web/live/ministry_funds/new_live.ex`

**Reference:** [`lib/churchapp_web/live/contributions/new_live.ex`](lib/churchapp_web/live/contributions/new_live.ex:1)

**Features:**
- Ministry selector with custom ministry modal
- Transaction type radio buttons (Revenue/Expense)
- Amount input (single field, always positive)
- Transaction date picker (default to today)
- Notes textarea
- Real-time validation

**Key State:**
```elixir
@form - AshPhoenix form
@ministries - List of ministry options
@transaction_type - :revenue or :expense
@show_custom_ministry_modal - boolean
@custom_ministry_input - string
```

**Transaction Type Toggle:**
```elixir
def handle_event("set_transaction_type", %{"type" => type}, socket) do
  type_atom = String.to_existing_atom(type)
  
  form = socket.assigns.form.source
    |> Form.validate(%{"transaction_type" => type_atom})
    |> to_form()
  
  {:noreply, 
   socket
   |> assign(:transaction_type, type_atom)
   |> assign(:form, form)}
end
```

**Custom Ministry Modal:**
Similar to custom contribution type in [`new_live.ex`](lib/churchapp_web/live/contributions/new_live.ex:40)

---

### Step 8: Create Show LiveView

**File:** `lib/churchapp_web/live/ministry_funds/show_live.ex`

**Reference:** [`lib/churchapp_web/live/contributions/show_live.ex`](lib/churchapp_web/live/contributions/show_live.ex:1)

**Features:**
- Display transaction details
- Show ministry balance (all transactions for this ministry)
- List recent transactions for same ministry (last 5)
- Edit/Delete actions
- Back to list navigation

**Key Assigns:**
```elixir
@ministry_fund - Current transaction
@ministry_balance - Calculated balance
@recent_transactions - Last 5 for same ministry
```

---

### Step 9: Create Edit LiveView

**File:** `lib/churchapp_web/live/ministry_funds/edit_live.ex`

**Reference:** [`lib/churchapp_web/live/contributions/edit_live.ex`](lib/churchapp_web/live/contributions/edit_live.ex:1)

**Features:**
- Same form as New page but pre-populated
- Maintain transaction type toggle logic
- Update validation
- Cannot change ministry name (or allow with warning)

---

### Step 10: Add Routes

**File:** [`lib/churchapp_web/router.ex`](lib/churchapp_web/router.ex:1)

**Add to `:authenticated` live_session:**
```elixir
live "/ministry-funds", MinistryFundsLive.IndexLive, :index
live "/ministry-funds/new", MinistryFundsLive.NewLive, :new
live "/ministry-funds/:id", MinistryFundsLive.ShowLive, :show
live "/ministry-funds/:id/edit", MinistryFundsLive.EditLive, :edit
```

---

### Step 11: Update Navigation

**File:** [`lib/churchapp_web/components/layouts/app.html.heex`](lib/churchapp_web/components/layouts/app.html.heex:1)

**Add navigation link:**
```heex
<.link
  navigate={~p"/ministry-funds"}
  class={[
    "flex items-center px-4 py-3 text-sm font-medium rounded-md transition-colors",
    @current_page == :ministry_funds && "bg-primary-500 text-white",
    @current_page != :ministry_funds && "text-gray-300 hover:bg-dark-700 hover:text-white"
  ]}
>
  <.icon name="hero-banknotes" class="mr-3 h-5 w-5" />
  Ministry Funds
</.link>
```

**Update `current_page` logic in layout module if needed**

---

### Step 12: Test Implementation

**Run:**
```bash
# Compile and check for errors
mix compile

# Run migrations
mix ecto.migrate

# Start server
mix phx.server

# Run tests (if created)
mix test
```

**Manual Testing Checklist:**
- [ ] Navigate to /ministry-funds
- [ ] Create new revenue transaction
- [ ] Create new expense transaction
- [ ] Verify balance calculation is correct
- [ ] Test search functionality
- [ ] Test filters (ministry, type, date, amount)
- [ ] Test pagination
- [ ] Test bulk selection and deletion
- [ ] Test edit transaction
- [ ] Test delete single transaction
- [ ] Verify dark mode consistency
- [ ] Test with different user roles
- [ ] Test custom ministry creation
- [ ] Test transaction type toggle (only one field active)

---

## UI/UX Guidelines

### Color Coding
- **Revenue**: Green (`text-green-400`, `border-green-500`)
- **Expense**: Red (`text-red-400`, `border-red-500`)
- **Positive Balance**: Green
- **Negative Balance**: Red
- **Zero Balance**: Gray

### Transaction Type Toggle
```heex
<div class="grid grid-cols-2 gap-4 mb-6">
  <label class={[
    "flex items-center justify-center px-4 py-3 rounded-lg border-2 cursor-pointer transition-all",
    @transaction_type == :revenue && "border-green-500 bg-green-500/10",
    @transaction_type != :revenue && "border-dark-700 hover:border-dark-600"
  ]}>
    <input 
      type="radio" 
      name="transaction_type" 
      value="revenue"
      checked={@transaction_type == :revenue}
      phx-click="set_transaction_type"
      phx-value-type="revenue"
      class="sr-only"
    />
    <.icon name="hero-arrow-trending-up" class="mr-2 h-5 w-5 text-green-400" />
    <span class="font-medium text-white">Revenue</span>
  </label>
  
  <label class={[
    "flex items-center justify-center px-4 py-3 rounded-lg border-2 cursor-pointer transition-all",
    @transaction_type == :expense && "border-red-500 bg-red-500/10",
    @transaction_type != :expense && "border-dark-700 hover:border-dark-600"
  ]}>
    <input 
      type="radio" 
      name="transaction_type" 
      value="expense"
      checked={@transaction_type == :expense}
      phx-click="set_transaction_type"
      phx-value-type="expense"
      class="sr-only"
    />
    <.icon name="hero-arrow-trending-down" class="mr-2 h-5 w-5 text-red-400" />
    <span class="font-medium text-white">Expense</span>
  </label>
</div>
```

### Balance Display
```heex
<div class="bg-dark-800 rounded-lg p-6 border border-dark-700">
  <div class="flex items-center justify-between">
    <div>
      <p class="text-sm text-gray-400">Current Balance</p>
      <p class={[
        "text-3xl font-bold mt-1",
        Decimal.positive?(@balance) && "text-green-400",
        Decimal.negative?(@balance) && "text-red-400",
        Decimal.equal?(@balance, Decimal.new(0)) && "text-gray-400"
      ]}>
        ${Decimal.to_string(@balance, :normal)}
      </p>
    </div>
    <div class={[
      "p-3 rounded-full",
      Decimal.positive?(@balance) && "bg-green-500/10",
      Decimal.negative?(@balance) && "bg-red-500/10"
    ]}>
      <.icon 
        name={if Decimal.positive?(@balance), do: "hero-arrow-trending-up", else: "hero-arrow-trending-down"}
        class={[
          "h-8 w-8",
          Decimal.positive?(@balance) && "text-green-400",
          Decimal.negative?(@balance) && "text-red-400"
        ]}
      />
    </div>
  </div>
</div>
```

---

## Common Pitfalls to Avoid

1. **Don't use negative amounts** - Store all amounts as positive, use `transaction_type` to distinguish
2. **Don't forget indexes** - Add database indexes for performance
3. **Don't skip authorization** - Always check user permissions
4. **Don't allow both fields active** - Only revenue OR expense should be editable at once
5. **Don't forget validation** - Validate on both client and server
6. **Don't hardcode ministries** - Use dynamic list from database + defaults
7. **Don't forget dark mode** - Test all UI in dark theme
8. **Don't skip pagination** - Large datasets need pagination
9. **Don't calculate balance in database** - Calculate in application layer for flexibility
10. **Don't forget error handling** - Handle all edge cases gracefully

---

## Verification Checklist

Before marking complete, verify:

- [ ] All files created and in correct locations
- [ ] Database migration runs successfully
- [ ] Ash resource compiles without errors
- [ ] Domain configuration updated
- [ ] All LiveView pages render correctly
- [ ] Ministry selector component works
- [ ] Routes accessible and working
- [ ] Navigation link appears and works
- [ ] Authorization policies enforced
- [ ] Balance calculations accurate
- [ ] Transaction type toggle works correctly
- [ ] Search and filters functional
- [ ] Pagination works
- [ ] Bulk operations work
- [ ] Dark mode consistent throughout
- [ ] No console errors
- [ ] Mobile responsive
- [ ] Accessible (keyboard navigation, screen readers)

---

## Next Steps After Implementation

1. **Create Tests**: Write comprehensive test suite
2. **Add Documentation**: Update user documentation
3. **Performance Testing**: Test with large datasets
4. **User Acceptance Testing**: Get feedback from users
5. **Monitor**: Watch for errors in production
6. **Iterate**: Improve based on feedback

---

## Support Resources

- **Ash Framework Docs**: https://hexdocs.pm/ash/
- **Phoenix LiveView Docs**: https://hexdocs.pm/phoenix_live_view/
- **Existing Code Patterns**: Reference contributions module for similar patterns
- **Specification**: [`MINISTRY_FUNDS_SPEC.md`](MINISTRY_FUNDS_SPEC.md:1)
- **Architecture**: [`MINISTRY_FUNDS_ARCHITECTURE.md`](MINISTRY_FUNDS_ARCHITECTURE.md:1)