# Ministry Funds Feature - Technical Specification

## Overview
A comprehensive financial tracking system for church ministries that allows recording revenue and expense transactions, with automatic balance calculations and full audit trails.

## Requirements Summary

### Core Features
1. **Dynamic Ministry Management**: Use existing ministry list with ability to add custom ministries through the web interface
2. **Transaction Tracking**: Individual revenue/expense transactions with dates and notes
3. **Balance Calculation**: Automatic calculation of balance per ministry (Total Revenues - Total Expenses)
4. **Ministry Association**: Each transaction is linked to a specific ministry (not congregants)
5. **Revenue/Expense Toggle**: When entering a transaction, only one field (revenue OR expense) should be active to prevent errors
6. **Dark Mode**: Maintain consistent dark theme throughout
7. **Authorization**: Role-based access control following existing patterns

## Database Schema

### Table: `ministry_funds`
```sql
CREATE TABLE ministry_funds (
  id UUID PRIMARY KEY,
  ministry_name VARCHAR NOT NULL,
  transaction_type VARCHAR NOT NULL CHECK (transaction_type IN ('revenue', 'expense')),
  amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
  transaction_date TIMESTAMP NOT NULL,
  notes TEXT,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_ministry_funds_ministry_name ON ministry_funds(ministry_name);
CREATE INDEX idx_ministry_funds_transaction_date ON ministry_funds(transaction_date);
CREATE INDEX idx_ministry_funds_transaction_type ON ministry_funds(transaction_type);
```

### Key Design Decisions
- **Single Amount Field**: Store amount as positive value, use `transaction_type` to distinguish revenue vs expense
- **Ministry Name**: Store as string (not FK) to allow dynamic ministry creation
- **Transaction Type**: Enum constraint ensures only 'revenue' or 'expense'
- **Indexes**: Optimize queries by ministry name, date, and transaction type

## Ash Resource Structure

### Resource: `Chms.Church.MinistryFunds`

**Attributes:**
- `id` (uuid_primary_key)
- `ministry_name` (string, required) - Name of the ministry
- `transaction_type` (atom, required) - Either `:revenue` or `:expense`
- `amount` (decimal, required) - Transaction amount (always positive)
- `transaction_date` (utc_datetime_usec, required) - When transaction occurred
- `notes` (string, optional) - Additional details
- `inserted_at` (create_timestamp)
- `updated_at` (update_timestamp)

**Actions:**
- `create` - Create new transaction
- `read` - List/query transactions
- `update` - Modify existing transaction
- `destroy` - Delete transaction

**Calculations:**
- Ministry balance calculation (aggregated in LiveView)
- Total revenues per ministry
- Total expenses per ministry

**Policies:**
- Super admins: Full access
- Admins/Staff: Create, read, update, delete
- Leaders: Read only
- Members: No access (or read only if needed)

## Module Updates

### 1. Update `Chms.Church.Ministries`
Transform from static list to dynamic system:

```elixir
defmodule Chms.Church.Ministries do
  @default_ministries [
    "Worship", "Royal Rangers", "Evangelism", "Women", "Men",
    "Girls", "Children", "Pro-Presenter", "Dance", "Missions",
    "Pastor", "Pastor's Wife", "Media", "Sound", "Kitchen",
    "Properties-admin", "Education", "Deacon", "Deaconess",
    "Ushers", "Youth", "General Secretary", "Trustees"
  ]

  def default_ministries, do: @default_ministries

  def all_ministries do
    # Get unique ministry names from database
    custom_ministries = 
      Chms.Church.MinistryFunds
      |> Ash.Query.select([:ministry_name])
      |> Ash.read!()
      |> Enum.map(& &1.ministry_name)
      |> Enum.uniq()

    (@default_ministries ++ custom_ministries)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def ministry_options do
    all_ministries()
    |> Enum.map(&{&1, &1})
  end
end
```

## LiveView Structure

### 1. Index Page (`lib/churchapp_web/live/ministry_funds/index_live.ex`)

**Features:**
- List all transactions grouped by ministry or chronologically
- Search by ministry name, notes
- Filter by:
  - Ministry name
  - Transaction type (revenue/expense/all)
  - Date range
  - Amount range
- Display running balance per ministry
- Bulk selection and deletion
- Pagination
- Summary statistics (total revenues, total expenses, net balance)

**Key Assigns:**
```elixir
@ministry_funds - List of transactions
@ministry_balances - Map of ministry_name => balance
@search_query - Search term
@ministry_filter - Selected ministry
@type_filter - revenue/expense/all
@date_from, @date_to - Date range
@amount_min, @amount_max - Amount range
@selected_ids - Bulk selection
@page, @per_page, @total_count, @total_pages - Pagination
```

### 2. New Page (`lib/churchapp_web/live/ministry_funds/new_live.ex`)

**Features:**
- Ministry selector (searchable dropdown with custom entry)
- Transaction type radio buttons (Revenue/Expense)
- Amount input (only one active based on transaction type)
- Transaction date picker
- Notes textarea
- Real-time validation
- Modal for adding custom ministry

**Key Logic:**
```elixir
# When transaction_type changes, ensure proper field state
def handle_event("toggle_transaction_type", %{"type" => type}, socket) do
  # Update form to reflect new transaction type
  # Clear the opposite field if needed
end
```

### 3. Show Page (`lib/churchapp_web/live/ministry_funds/show_live.ex`)

**Features:**
- Display transaction details
- Show ministry balance (calculated from all transactions)
- List recent transactions for same ministry
- Edit/Delete actions
- Navigation back to list

### 4. Edit Page (`lib/churchapp_web/live/ministry_funds/edit_live.ex`)

**Features:**
- Same form as New page but pre-populated
- Maintain transaction type toggle logic
- Update validation

## Component Structure

### Ministry Selector Component
**File:** `lib/churchapp_web/components/ministry_selector.ex`

Similar to [`ContributionTypeSelector`](lib/churchapp_web/components/contribution_type_selector.ex:1), provides:
- Searchable dropdown
- Keyboard navigation
- Custom ministry entry
- Real-time filtering

## UI/UX Design

### Color Scheme (Dark Mode)
- Background: `bg-dark-900` (#121212)
- Cards: `bg-dark-800` (#1E1E1E)
- Borders: `border-dark-700` (#2D2D2D)
- Primary: `text-primary-500` (#06b6d4)
- Revenue: `text-green-400` (positive transactions)
- Expense: `text-red-400` (negative transactions)
- Balance: Dynamic color based on positive/negative

### Key UI Elements
1. **Transaction Type Toggle**: Radio buttons or toggle switch
2. **Amount Input**: Single field with currency formatting
3. **Balance Display**: Prominent card showing ministry balance
4. **Transaction List**: Table with color-coded transaction types
5. **Summary Cards**: Total revenues, total expenses, net balance

## Form Validation

### Client-Side (LiveView)
- Ministry name required
- Transaction type required (revenue or expense)
- Amount required, must be positive
- Transaction date required, cannot be future date
- Notes optional, max 1000 characters

### Server-Side (Ash Resource)
- Amount constraints: `precision: 10, scale: 2, min: 0`
- Transaction type: `one_of: [:revenue, :expense]`
- Ministry name: `allow_nil? false`
- Transaction date: `allow_nil? false`

## Revenue/Expense Toggle Logic

### Implementation Strategy
```elixir
# In the form, use phx-change to toggle field states
<div class="grid grid-cols-2 gap-4">
  <label class="flex items-center">
    <input type="radio" name="transaction_type" value="revenue" 
           phx-click="set_transaction_type" phx-value-type="revenue"
           checked={@transaction_type == :revenue} />
    <span>Revenue</span>
  </label>
  <label class="flex items-center">
    <input type="radio" name="transaction_type" value="expense"
           phx-click="set_transaction_type" phx-value-type="expense"
           checked={@transaction_type == :expense} />
    <span>Expense</span>
  </label>
</div>

<div class="mt-4">
  <label>Amount</label>
  <.input 
    field={@form[:amount]}
    type="number"
    step="0.01"
    disabled={@transaction_type == nil}
    class={[@transaction_type == :revenue && "border-green-500",
            @transaction_type == :expense && "border-red-500"]}
  />
</div>
```

## Balance Calculation

### Per Ministry Balance
```elixir
def calculate_ministry_balance(ministry_name) do
  transactions = 
    Chms.Church.MinistryFunds
    |> Ash.Query.filter(ministry_name == ^ministry_name)
    |> Ash.read!()

  revenues = 
    transactions
    |> Enum.filter(&(&1.transaction_type == :revenue))
    |> Enum.map(&Decimal.to_float(&1.amount))
    |> Enum.sum()

  expenses = 
    transactions
    |> Enum.filter(&(&1.transaction_type == :expense))
    |> Enum.map(&Decimal.to_float(&1.amount))
    |> Enum.sum()

  Decimal.sub(Decimal.from_float(revenues), Decimal.from_float(expenses))
end
```

### All Ministries Summary
```elixir
def calculate_all_balances do
  transactions = Ash.read!(Chms.Church.MinistryFunds)
  
  transactions
  |> Enum.group_by(& &1.ministry_name)
  |> Enum.map(fn {ministry, txns} ->
    balance = calculate_balance_from_transactions(txns)
    {ministry, balance}
  end)
  |> Map.new()
end
```

## Router Configuration

```elixir
# In lib/churchapp_web/router.ex
scope "/", ChurchappWeb do
  pipe_through :browser

  ash_authentication_live_session :authenticated,
    on_mount: [{ChurchappWeb.LiveUserAuth, :live_user_required}] do
    
    # ... existing routes ...
    
    live "/ministry-funds", MinistryFundsLive.IndexLive, :index
    live "/ministry-funds/new", MinistryFundsLive.NewLive, :new
    live "/ministry-funds/:id", MinistryFundsLive.ShowLive, :show
    live "/ministry-funds/:id/edit", MinistryFundsLive.EditLive, :edit
  end
end
```

## Navigation Update

Add to sidebar navigation in [`layouts/app.html.heex`](lib/churchapp_web/components/layouts/app.html.heex:1):

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

## Authorization Policies

```elixir
policies do
  # Super admins bypass all policies
  bypass action_type([:create, :read, :update, :destroy]) do
    authorize_if {Checks.IsSuperAdmin, []}
  end

  # Read policy
  policy action_type(:read) do
    authorize_if {Checks.HasRole, role: [:admin, :staff, :leader]}
    authorize_if {Checks.HasPermission, permission: :view_ministry_funds}
  end

  # Write policies
  policy action_type([:create, :update, :destroy]) do
    authorize_if {Checks.HasRole, role: [:admin, :staff]}
    authorize_if {Checks.HasPermission, permission: :manage_ministry_funds}
  end
end
```

## Testing Strategy

### Unit Tests
1. Test balance calculations with various transaction combinations
2. Test ministry name validation and uniqueness
3. Test transaction type constraints
4. Test amount validation (positive values only)

### Integration Tests
1. Test creating revenue transaction
2. Test creating expense transaction
3. Test editing transactions
4. Test deleting transactions
5. Test balance calculation accuracy
6. Test ministry filtering
7. Test date range filtering
8. Test search functionality

### LiveView Tests
1. Test form validation
2. Test transaction type toggle
3. Test custom ministry creation
4. Test bulk operations
5. Test pagination
6. Test authorization (different user roles)

## Migration Path

1. Create migration for `ministry_funds` table
2. Create Ash resource
3. Update domain configuration
4. Update Ministries module
5. Create LiveView pages (index → new → show → edit)
6. Create ministry selector component
7. Add routes
8. Update navigation
9. Test thoroughly
10. Deploy

## Future Enhancements

1. **Budget Planning**: Set budget targets per ministry
2. **Reporting**: Generate financial reports (monthly, quarterly, yearly)
3. **Export**: Export transactions to CSV/PDF
4. **Attachments**: Upload receipts/invoices
5. **Approval Workflow**: Require approval for large expenses
6. **Recurring Transactions**: Auto-create monthly expenses
7. **Multi-Currency**: Support different currencies
8. **Charts**: Visualize revenue/expense trends

## File Structure

```
lib/
├── chms/
│   └── church/
│       └── ministry_funds.ex (NEW)
├── churchapp_web/
│   ├── components/
│   │   └── ministry_selector.ex (NEW)
│   └── live/
│       └── ministry_funds/ (NEW)
│           ├── index_live.ex
│           ├── new_live.ex
│           ├── show_live.ex
│           └── edit_live.ex
priv/
└── repo/
    └── migrations/
        └── YYYYMMDDHHMMSS_add_ministry_funds.exs (NEW)
```

## Success Criteria

✅ Users can create ministries dynamically through the web interface
✅ Users can record revenue transactions for ministries
✅ Users can record expense transactions for ministries
✅ Only one field (revenue OR expense) is active at a time
✅ Balance is calculated correctly as (Total Revenues - Total Expenses)
✅ Transactions are linked to ministries (not congregants)
✅ Full CRUD operations work correctly
✅ Search and filtering work as expected
✅ Dark mode is consistent throughout
✅ Authorization policies are enforced
✅ UI matches existing design patterns