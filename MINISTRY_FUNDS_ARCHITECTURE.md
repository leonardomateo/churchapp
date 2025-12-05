# Ministry Funds - System Architecture

## High-Level Architecture

```mermaid
graph TB
    subgraph "User Interface Layer"
        UI[LiveView Pages]
        UI --> Index[Index Page<br/>List & Filter]
        UI --> New[New Page<br/>Create Transaction]
        UI --> Show[Show Page<br/>View Details]
        UI --> Edit[Edit Page<br/>Update Transaction]
    end

    subgraph "Component Layer"
        MS[Ministry Selector<br/>Component]
        Index --> MS
        New --> MS
        Edit --> MS
    end

    subgraph "Business Logic Layer"
        Domain[Chms.Church Domain]
        Resource[MinistryFunds<br/>Ash Resource]
        Ministries[Ministries Module<br/>Dynamic List]
        
        Domain --> Resource
        Domain --> Ministries
    end

    subgraph "Data Layer"
        DB[(PostgreSQL<br/>ministry_funds table)]
        Resource --> DB
        Ministries -.reads from.-> DB
    end

    subgraph "Authorization Layer"
        Auth[Ash Policies]
        Checks[Authorization Checks]
        Auth --> Checks
        Resource --> Auth
    end

    UI --> Domain
    MS --> Ministries
```

## Data Flow - Creating a Transaction

```mermaid
sequenceDiagram
    actor User
    participant NewLive as New Page
    participant MS as Ministry Selector
    participant Form as AshPhoenix Form
    participant Resource as MinistryFunds Resource
    participant Auth as Authorization
    participant DB as Database

    User->>NewLive: Navigate to /ministry-funds/new
    NewLive->>Form: Initialize empty form
    NewLive->>MS: Load ministry options
    MS->>Resource: Query existing ministries
    Resource->>DB: SELECT DISTINCT ministry_name
    DB-->>MS: Return ministry list
    MS-->>NewLive: Display ministry dropdown

    User->>NewLive: Select ministry
    User->>NewLive: Choose transaction type (Revenue/Expense)
    NewLive->>NewLive: Toggle field states
    User->>NewLive: Enter amount
    User->>NewLive: Add notes
    User->>NewLive: Submit form

    NewLive->>Form: Validate form data
    Form->>Resource: Create action with params
    Resource->>Auth: Check permissions
    Auth-->>Resource: Authorized
    Resource->>DB: INSERT INTO ministry_funds
    DB-->>Resource: Transaction created
    Resource-->>NewLive: Success
    NewLive->>User: Redirect to index with flash message
```

## Balance Calculation Flow

```mermaid
graph LR
    subgraph "Index Page Load"
        A[Load Transactions] --> B[Group by Ministry]
        B --> C[Calculate Per Ministry]
    end

    subgraph "Per Ministry Calculation"
        C --> D[Sum Revenues]
        C --> E[Sum Expenses]
        D --> F[Balance = Revenues - Expenses]
        E --> F
    end

    subgraph "Display"
        F --> G[Show in UI]
        G --> H[Color Code:<br/>Green if positive<br/>Red if negative]
    end
```

## Component Interaction - Ministry Selector

```mermaid
graph TB
    subgraph "Ministry Selector Component"
        Input[Search Input]
        Dropdown[Dropdown List]
        Custom[Add Custom Button]
        Modal[Custom Ministry Modal]
        
        Input --> Filter[Filter Ministries]
        Filter --> Dropdown
        Custom --> Modal
        Modal --> Add[Add to List]
        Add --> Dropdown
    end

    subgraph "Data Sources"
        Default[Default Ministries<br/>Predefined List]
        DB[Database<br/>Custom Ministries]
        
        Default --> Merge[Merge & Sort]
        DB --> Merge
        Merge --> Filter
    end

    subgraph "Parent Form"
        Form[LiveView Form]
        Hidden[Hidden Input<br/>ministry_name]
        
        Dropdown --> Select[User Selects]
        Select --> Hidden
        Hidden --> Form
    end
```

## Database Schema Relationships

```mermaid
erDiagram
    MINISTRY_FUNDS {
        uuid id PK
        string ministry_name
        string transaction_type
        decimal amount
        timestamp transaction_date
        text notes
        timestamp inserted_at
        timestamp updated_at
    }

    MINISTRY_FUNDS ||--o{ TRANSACTIONS : "groups by ministry_name"
    
    note "No foreign key - allows dynamic ministry creation"
```

## Authorization Flow

```mermaid
graph TB
    Request[User Request] --> Session[Check Session]
    Session --> User{User<br/>Authenticated?}
    User -->|No| Deny[Deny Access]
    User -->|Yes| Role{Check Role}
    
    Role -->|Super Admin| Allow[Full Access]
    Role -->|Admin/Staff| Write{Action Type?}
    Role -->|Leader| Read[Read Only]
    Role -->|Member| Deny
    
    Write -->|Read| Allow
    Write -->|Create/Update/Delete| Allow
```

## UI State Management - Transaction Type Toggle

```mermaid
stateDiagram-v2
    [*] --> Initial: Page Load
    Initial --> Revenue: Select Revenue
    Initial --> Expense: Select Expense
    
    Revenue --> AmountActive: Enable Amount Field
    Expense --> AmountActive: Enable Amount Field
    
    AmountActive --> Revenue: Switch to Revenue
    AmountActive --> Expense: Switch to Expense
    
    Revenue --> Validate: Enter Amount
    Expense --> Validate: Enter Amount
    
    Validate --> Submit: Valid
    Validate --> Error: Invalid
    Error --> AmountActive: Fix Errors
    
    Submit --> [*]: Save Transaction
```

## File Organization

```
churchapp/
├── lib/
│   ├── chms/
│   │   └── church/
│   │       ├── congregants.ex
│   │       ├── contributions.ex
│   │       ├── contribution_types.ex
│   │       ├── ministries.ex (UPDATED)
│   │       ├── ministry_funds.ex (NEW)
│   │       └── statistics.ex
│   │
│   └── churchapp_web/
│       ├── components/
│       │   ├── congregant_selector.ex
│       │   ├── contribution_type_selector.ex
│       │   ├── ministry_selector.ex (NEW)
│       │   └── core_components.ex
│       │
│       ├── live/
│       │   ├── congregants/
│       │   ├── contributions/
│       │   ├── dashboard/
│       │   ├── ministry_funds/ (NEW)
│       │   │   ├── index_live.ex
│       │   │   ├── new_live.ex
│       │   │   ├── show_live.ex
│       │   │   └── edit_live.ex
│       │   └── users/
│       │
│       └── router.ex (UPDATED)
│
└── priv/
    └── repo/
        └── migrations/
            └── YYYYMMDDHHMMSS_add_ministry_funds.exs (NEW)
```

## Key Design Patterns

### 1. Transaction Type Pattern
- **Single Amount Field**: Store positive values only
- **Type Discriminator**: Use `transaction_type` enum
- **UI Toggle**: Radio buttons or toggle switch
- **Validation**: Ensure only one type per transaction

### 2. Dynamic List Pattern (Like Contribution Types)
- **Default Values**: Predefined ministry list
- **Database Query**: Fetch custom ministries
- **Merge & Sort**: Combine both sources
- **Searchable Dropdown**: LiveComponent with filtering

### 3. Balance Calculation Pattern
- **Aggregate on Read**: Calculate when displaying
- **Group by Ministry**: Organize transactions
- **Sum by Type**: Separate revenue and expense totals
- **Subtract**: Balance = Revenues - Expenses

### 4. Form Validation Pattern
- **Client-Side**: LiveView phx-change events
- **Server-Side**: Ash resource constraints
- **Real-Time Feedback**: Update UI immediately
- **Error Display**: Show validation errors inline

## Performance Considerations

### Indexing Strategy
```sql
-- Primary queries
CREATE INDEX idx_ministry_funds_ministry_name ON ministry_funds(ministry_name);
CREATE INDEX idx_ministry_funds_transaction_date ON ministry_funds(transaction_date);
CREATE INDEX idx_ministry_funds_transaction_type ON ministry_funds(transaction_type);

-- Composite index for common query pattern
CREATE INDEX idx_ministry_funds_ministry_date 
  ON ministry_funds(ministry_name, transaction_date DESC);
```

### Query Optimization
- Use Ash Query filters for database-level filtering
- Paginate large result sets
- Cache ministry list in LiveView assigns
- Calculate balances in memory after fetching transactions

### LiveView Optimization
- Use streams for large transaction lists
- Debounce search inputs
- Lazy load transaction details
- Cache calculated balances per page load

## Security Considerations

1. **Authorization**: Enforce at resource level with Ash policies
2. **Input Validation**: Sanitize all user inputs
3. **SQL Injection**: Use parameterized queries (Ash handles this)
4. **XSS Prevention**: Phoenix auto-escapes HTML
5. **CSRF Protection**: Phoenix built-in protection
6. **Amount Validation**: Ensure positive values only
7. **Date Validation**: Prevent future dates if needed

## Accessibility Features

1. **Keyboard Navigation**: Full keyboard support in selectors
2. **ARIA Labels**: Proper labels for screen readers
3. **Focus Management**: Logical tab order
4. **Color Contrast**: WCAG AA compliant
5. **Error Announcements**: Screen reader friendly errors
6. **Form Labels**: All inputs properly labeled

## Responsive Design

- **Mobile First**: Design for small screens
- **Breakpoints**: sm, md, lg, xl
- **Touch Targets**: Minimum 44x44px
- **Horizontal Scroll**: Prevent on mobile
- **Collapsible Filters**: Hide on mobile by default
- **Stacked Layout**: Single column on mobile

## Testing Strategy

### Unit Tests
- Balance calculation logic
- Ministry list merging
- Transaction type validation
- Amount constraints

### Integration Tests
- CRUD operations
- Authorization checks
- Database constraints
- Query performance

### LiveView Tests
- Form submission
- Field toggling
- Search/filter
- Pagination
- Bulk operations

### E2E Tests
- Complete user flows
- Multi-user scenarios
- Error handling
- Edge cases