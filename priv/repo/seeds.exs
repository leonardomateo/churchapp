# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Churchapp.Repo.insert!(%Churchapp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Seed Users with different roles
IO.puts("Seeding users...")

# Helper function to create or skip existing users
create_user = fn attrs ->
  case Churchapp.Accounts.User
       |> Ash.Changeset.for_create(:register_with_password, attrs)
       |> Ash.create(authorize?: false) do
    {:ok, user} ->
      IO.puts("✓ Created user: #{attrs.email}")
      user

    {:error, %{errors: errors}} ->
      already_exists? =
        Enum.any?(errors, fn e ->
          is_map(e) and Map.get(e, :field) == :email and
            Map.get(e, :message) == "has already been taken"
        end)

      if already_exists? do
        IO.puts("⊙ User already exists: #{attrs.email}")
        nil
      else
        IO.puts("✗ Failed to create user: #{attrs.email}")
        IO.inspect(errors)
        nil
      end
  end
end

# Create super admin user
_super_admin =
  create_user.(%{
    email: "superadmin@church.org",
    password: "SuperAdmin123!",
    password_confirmation: "SuperAdmin123!",
    role: :super_admin,
    permissions: [
      :manage_congregants,
      :view_congregants,
      :manage_contributions,
      :view_contributions,
      :manage_ministries,
      :view_reports,
      :manage_users
    ]
  })

# Create admin user
_admin =
  create_user.(%{
    email: "admin@church.org",
    password: "Admin123!",
    password_confirmation: "Admin123!",
    role: :admin,
    permissions: [
      :manage_congregants,
      :view_congregants,
      :manage_contributions,
      :view_contributions,
      :manage_ministries,
      :view_reports
    ]
  })

# Create staff user
_staff =
  create_user.(%{
    email: "staff@church.org",
    password: "Staff123!",
    password_confirmation: "Staff123!",
    role: :staff,
    permissions: [
      :manage_congregants,
      :view_congregants,
      :view_contributions
    ]
  })

# Create leader user
_leader =
  create_user.(%{
    email: "leader@church.org",
    password: "Leader123!",
    password_confirmation: "Leader123!",
    role: :leader,
    permissions: [:view_congregants, :view_contributions]
  })

# Create regular member
_member =
  create_user.(%{
    email: "member@church.org",
    password: "Member123!",
    password_confirmation: "Member123!",
    role: :member,
    permissions: [:view_congregants]
  })

IO.puts("")

# Seed Congregants
IO.puts("Seeding 150 congregants from Latin America, USA, and Canada...")

# Latin American countries + USA and Canada
# Weighted to have more Dominican Republic congregants
# 5x weight for Dominican Republic
countries =
  List.duplicate("Dominican Republic", 5) ++
    [
      "Mexico",
      "Colombia",
      "Venezuela",
      "Peru",
      "Argentina",
      "Chile",
      "Ecuador",
      "Guatemala",
      "Cuba",
      "Honduras",
      "El Salvador",
      "USA",
      "Canada"
    ]

# Common Latin American first names
first_names = [
  "Juan",
  "Maria",
  "Jose",
  "Ana",
  "Carlos",
  "Carmen",
  "Luis",
  "Rosa",
  "Miguel",
  "Isabel",
  "Pedro",
  "Sofia",
  "Jorge",
  "Elena",
  "Francisco",
  "Laura",
  "Antonio",
  "Patricia",
  "Manuel",
  "Teresa",
  "Rafael",
  "Lucia",
  "Fernando",
  "Gabriela",
  "Roberto",
  "Valentina",
  "Diego",
  "Camila",
  "Alejandro",
  "Andrea",
  "Ricardo",
  "Monica",
  "Javier",
  "Daniela",
  "Sergio",
  "Natalia",
  "Pablo",
  "Victoria",
  "Andres",
  "Mariana",
  "Raul",
  "Adriana",
  "Oscar",
  "Beatriz",
  "Enrique",
  "Claudia",
  "Hector",
  "Silvia",
  "Arturo",
  "Veronica",
  "Gustavo",
  "Paola",
  "Eduardo",
  "Cristina",
  "Alberto",
  "Sandra",
  "Julio",
  "Diana",
  "Cesar",
  "Alejandra",
  "Felipe",
  "Lorena",
  "Rodrigo",
  "Angelica",
  "Mauricio",
  "Fernanda",
  "Ernesto",
  "Juliana",
  "Armando",
  "Carolina",
  "Victor",
  "Marcela",
  "Ramon",
  "Susana",
  "Guillermo",
  "Yolanda",
  "Ruben",
  "Cecilia",
  "Ignacio",
  "Alicia"
]

# Common Latin American last names
last_names = [
  "Garcia",
  "Rodriguez",
  "Martinez",
  "Hernandez",
  "Lopez",
  "Gonzalez",
  "Perez",
  "Sanchez",
  "Ramirez",
  "Torres",
  "Flores",
  "Rivera",
  "Gomez",
  "Diaz",
  "Cruz",
  "Morales",
  "Reyes",
  "Gutierrez",
  "Ortiz",
  "Chavez",
  "Ruiz",
  "Jimenez",
  "Mendoza",
  "Alvarez",
  "Castillo",
  "Romero",
  "Herrera",
  "Medina",
  "Aguilar",
  "Vargas",
  "Castro",
  "Ramos",
  "Moreno",
  "Guerrero",
  "Mendez",
  "Rojas",
  "Delgado",
  "Campos",
  "Vazquez",
  "Nunez",
  "Soto",
  "Contreras",
  "Luna",
  "Rios",
  "Mejia",
  "Dominguez",
  "Guzman",
  "Velasquez",
  "Salazar",
  "Pena"
]

# US States for USA congregants
us_states = ["New York", "California", "Texas", "Florida", "Illinois"]

# Canadian provinces
canadian_provinces = ["Ontario", "Quebec", "British Columbia", "Alberta"]

# Congregant statuses with distribution
# 60% member, 20% visitor, 15% honorific, 5% deceased
statuses =
  List.duplicate(:member, 90) ++
    List.duplicate(:visitor, 30) ++
    List.duplicate(:honorific, 23) ++
    List.duplicate(:deceased, 7)

# Generate 150 congregants
congregants_data =
  Enum.map(1..150, fn i ->
    country = Enum.random(countries)
    status = Enum.at(statuses, i - 1)

    # Determine state/province based on country
    {city, state} =
      case country do
        "USA" ->
          state = Enum.random(us_states)

          cities = %{
            "New York" => ["New York City", "Brooklyn", "Queens", "Manhattan", "Bronx"],
            "California" => ["Los Angeles", "San Francisco", "San Diego", "Sacramento"],
            "Texas" => ["Houston", "Dallas", "Austin", "San Antonio"],
            "Florida" => ["Miami", "Orlando", "Tampa", "Jacksonville"],
            "Illinois" => ["Chicago", "Springfield", "Naperville"]
          }

          {Enum.random(cities[state]), state}

        "Canada" ->
          province = Enum.random(canadian_provinces)

          cities = %{
            "Ontario" => ["Toronto", "Ottawa", "Mississauga", "Hamilton"],
            "Quebec" => ["Montreal", "Quebec City", "Laval"],
            "British Columbia" => ["Vancouver", "Victoria", "Surrey"],
            "Alberta" => ["Calgary", "Edmonton", "Red Deer"]
          }

          {Enum.random(cities[province]), province}

        _ ->
          # Latin American countries
          {"Capital City", "Central"}
      end

    # Generate random dates
    # 1-10 years
    days_member = Enum.random(365..3650)
    member_since = Date.add(Date.utc_today(), -days_member)

    # 18-70 years old
    days_old = Enum.random(6570..25550)
    dob = Date.add(Date.utc_today(), -days_old)

    %{
      first_name: Enum.random(first_names),
      last_name: Enum.random(last_names),
      address:
        "#{Enum.random(100..9999)} #{Enum.random(["Main", "Oak", "Maple", "Pine", "Elm"])} #{Enum.random(["St", "Ave", "Blvd", "Dr", "Ln"])}",
      suite: if(Enum.random(1..3) == 1, do: "Apt #{Enum.random(1..20)}", else: nil),
      city: city,
      state: state,
      zip_code: "#{Enum.random(10000..99999)}",
      country: country,
      mobile_tel:
        "(#{Enum.random(200..999)}) #{Enum.random(200..999)}-#{Enum.random(1000..9999)}",
      home_tel:
        if(Enum.random(1..3) == 1,
          do: "(#{Enum.random(200..999)}) #{Enum.random(200..999)}-#{Enum.random(1000..9999)}",
          else: nil
        ),
      work_tel:
        if(Enum.random(1..4) == 1,
          do: "(#{Enum.random(200..999)}) #{Enum.random(200..999)}-#{Enum.random(1000..9999)}",
          else: nil
        ),
      dob: dob,
      member_since: member_since,
      status: status,
      # 20% are leaders
      is_leader: Enum.random(1..5) == 1,
      gender: Enum.random([:male, :female])
    }
  end)

created_congregants =
  Enum.map(congregants_data, fn attrs ->
    # Check if congregant already exists by name and phone
    existing =
      case Chms.Church.Congregants
           |> Ash.Query.for_read(:read)
           |> Ash.read(authorize?: false) do
        {:ok, all_congregants} ->
          found =
            Enum.find(all_congregants, fn c ->
              c.first_name == attrs.first_name and c.last_name == attrs.last_name and
                c.mobile_tel == attrs.mobile_tel
            end)

          {:ok, found}

        error ->
          error
      end

    case existing do
      {:ok, nil} ->
        # Doesn't exist, create it
        case Chms.Church.Congregants
             |> Ash.Changeset.for_create(:create, attrs)
             |> Ash.create(authorize?: false) do
          {:ok, congregant} ->
            IO.puts(
              "✓ Created congregant: #{congregant.first_name} #{congregant.last_name} (#{congregant.country}) - Status: #{congregant.status}"
            )

            congregant

          {:error, changeset} ->
            IO.puts("✗ Failed to create congregant: #{attrs.first_name} #{attrs.last_name}")
            IO.inspect(changeset.errors)
            nil
        end

      {:ok, congregant} ->
        IO.puts("⊙ Congregant already exists: #{congregant.first_name} #{congregant.last_name}")

        congregant

      {:error, error} ->
        IO.puts(
          "✗ Error checking for existing congregant: #{attrs.first_name} #{attrs.last_name}"
        )

        IO.inspect(error)
        nil
    end
  end)
  |> Enum.reject(&is_nil/1)

IO.puts("\nTotal congregants created: #{length(created_congregants)}")

# Seed Contributions
IO.puts("\nSeeding 200 contributions...")

# Contribution types to use
contribution_types = [
  "Tithes",
  "General Offering",
  "Mission",
  "Building Fund",
  "Special Offering",
  "Youth Ministry",
  "Benevolence",
  "Music Ministry"
]

# Only create contributions for newly created congregants to avoid duplicates
newly_created_congregants =
  created_congregants
  |> Enum.filter(fn congregant ->
    # Check if this congregant has any contributions already
    case Chms.Church.Contributions
         |> Ash.Query.for_read(:read)
         |> Ash.read(authorize?: false) do
      {:ok, contributions} ->
        !Enum.any?(contributions, fn c -> c.congregant_id == congregant.id end)

      _ ->
        true
    end
  end)

IO.puts("Creating contributions for #{length(newly_created_congregants)} congregants...")

# Generate exactly 200 contributions distributed across congregants
contributions =
  if length(newly_created_congregants) > 0 do
    Enum.map(1..200, fn _ ->
      # Pick a random congregant
      congregant = Enum.random(newly_created_congregants)

      # Random datetime within the last 2 years
      days_ago = Enum.random(1..730)
      hours_ago = Enum.random(0..23)
      minutes_ago = Enum.random(0..59)

      contribution_date =
        DateTime.utc_now()
        |> DateTime.add(
          -days_ago * 24 * 60 * 60 - hours_ago * 60 * 60 - minutes_ago * 60,
          :second
        )
        |> DateTime.truncate(:second)

      # Random amount between $10 and $1000
      amount = Decimal.new(Enum.random(10..1000))

      # Random contribution type
      contribution_type = Enum.random(contribution_types)

      # 30% chance of having notes
      notes =
        if Enum.random(1..10) <= 3 do
          [
            "Thank you for your faithful giving",
            "God bless you",
            "Special donation for church anniversary",
            "Monthly tithe",
            "Extra offering for missions",
            "In memory of loved one",
            "Thanksgiving offering",
            "Christmas offering",
            "Easter offering",
            "Online donation"
          ]
          |> Enum.random()
        else
          nil
        end

      %{
        congregant_id: congregant.id,
        contribution_type: contribution_type,
        revenue: amount,
        contribution_date: contribution_date,
        notes: notes
      }
    end)
  else
    []
  end

Enum.each(contributions, fn attrs ->
  case Chms.Church.Contributions
       |> Ash.Changeset.for_create(:create, attrs)
       |> Ash.create(authorize?: false) do
    {:ok, contribution} ->
      IO.puts(
        "✓ Created contribution: #{contribution.contribution_type} - $#{Decimal.to_string(contribution.revenue, :normal)}"
      )

    {:error, changeset} ->
      IO.puts("✗ Failed to create contribution: #{attrs.contribution_type}")

      IO.inspect(changeset.errors)
  end
end)

IO.puts("\nSeeding ministry funds...")

# Ministry names to use
ministries = [
  "Youth Ministry",
  "Music Ministry",
  "Missions",
  "Benevolence",
  "Building Fund",
  "Children's Ministry",
  "Worship",
  "Outreach"
]

# Generate 100 ministry fund transactions
ministry_funds_data =
  Enum.map(1..100, fn _ ->
    ministry = Enum.random(ministries)
    transaction_type = Enum.random([:revenue, :expense])

    # Random datetime within the last year
    days_ago = Enum.random(1..365)
    hours_ago = Enum.random(0..23)
    minutes_ago = Enum.random(0..59)

    transaction_date =
      DateTime.utc_now()
      |> DateTime.add(
        -days_ago * 24 * 60 * 60 - hours_ago * 60 * 60 - minutes_ago * 60,
        :second
      )
      |> DateTime.truncate(:second)

    # Revenue amounts tend to be higher than expenses
    amount =
      case transaction_type do
        :revenue -> Decimal.new(Enum.random(500..5000))
        :expense -> Decimal.new(Enum.random(100..2000))
      end

    # Generate notes based on transaction type
    notes =
      case transaction_type do
        :revenue ->
          [
            "Fundraiser proceeds",
            "Donation received",
            "Ministry offering",
            "Special gift",
            "Grant received",
            "Event revenue",
            "Annual pledge",
            "Memorial gift"
          ]
          |> Enum.random()

        :expense ->
          [
            "Equipment purchase",
            "Event supplies",
            "Program materials",
            "Outreach expenses",
            "Ministry resources",
            "Facility rental",
            "Transportation costs",
            "Communication expenses"
          ]
          |> Enum.random()
      end

    %{
      ministry_name: ministry,
      transaction_type: transaction_type,
      amount: amount,
      transaction_date: transaction_date,
      notes: notes
    }
  end)

# Check for existing ministry funds to avoid duplicates
existing_ministry_funds =
  case Chms.Church.MinistryFunds
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, funds} -> funds
    _ -> []
  end

# Only create if we don't have existing data
ministry_funds_to_create =
  if length(existing_ministry_funds) > 0 do
    IO.puts("⊙ Ministry funds already exist, skipping seed")
    []
  else
    ministry_funds_data
  end

Enum.each(ministry_funds_to_create, fn attrs ->
  case Chms.Church.MinistryFunds
       |> Ash.Changeset.for_create(:create, attrs)
       |> Ash.create(authorize?: false) do
    {:ok, fund} ->
      type_icon = if fund.transaction_type == :revenue, do: "↑", else: "↓"
      type_color = if fund.transaction_type == :revenue, do: "✓", else: "✗"

      IO.puts(
        "#{type_color} Created #{fund.transaction_type}: #{fund.ministry_name} - $#{Decimal.to_string(fund.amount, :normal)} #{type_icon}"
      )

    {:error, changeset} ->
      IO.puts("✗ Failed to create ministry fund: #{attrs.ministry_name}")
      IO.inspect(changeset.errors)
  end
end)

# Seed Report Categories
IO.puts("\nSeeding report categories...")

# Check if categories already exist
existing_categories =
  case Chms.Church.ReportCategories
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, categories} -> categories
    _ -> []
  end

if length(existing_categories) > 0 do
  IO.puts("⊙ Report categories already exist, skipping seed")
else
  # Get default categories from the module
  default_categories = Chms.Church.ReportCategories.default_categories()

  Enum.each(default_categories, fn attrs ->
    attrs_with_active = Map.put(attrs, :is_active, true)

    case Chms.Church.ReportCategories
         |> Ash.Changeset.for_create(:create, attrs_with_active)
         |> Ash.create(authorize?: false) do
      {:ok, category} ->
        IO.puts("✓ Created category: #{category.display_name} (#{category.group})")

      {:error, changeset} ->
        IO.puts("✗ Failed to create category: #{attrs.display_name}")
        IO.inspect(changeset.errors)
    end
  end)
end

# Seed Week Ending Reports
IO.puts("\nSeeding week ending reports...")

# Get existing report end dates to avoid duplicates
existing_end_dates =
  case Chms.Church.WeekEndingReports
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, reports} -> Enum.map(reports, & &1.week_end_date)
    _ -> []
  end

# Get all active categories for creating entries
all_categories =
  case Chms.Church.ReportCategories
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, cats} -> cats
    _ -> []
  end

if length(all_categories) == 0 do
  IO.puts("⊙ No report categories found, skipping week ending reports seed")
else
  # Generate reports for the last 8 weeks
  today = Date.utc_today()

  # Find the most recent Sunday (end of week)
  days_since_sunday = Date.day_of_week(today, :sunday)
  last_sunday = Date.add(today, -days_since_sunday)

  # Generate 8 weeks of reports
  Enum.each(0..7, fn week_offset ->
    week_end = Date.add(last_sunday, -week_offset * 7)
    week_start = Date.add(week_end, -6)

    # Skip if a report with this end date already exists
    if week_end in existing_end_dates do
      IO.puts("⊙ Report for week ending #{week_end} already exists, skipping")
    else
      report_attrs = %{
        week_start_date: week_start,
        week_end_date: week_end,
        report_name: nil,
        notes:
          if Enum.random(1..3) == 1 do
            Enum.random([
              "Good attendance this week",
              "Special service with guest speaker",
              "Communion Sunday",
              "Youth-led worship service",
              "Annual thanksgiving service",
              "Normal service week",
              "Holiday weekend - lower attendance",
              "Building fund campaign kickoff"
            ])
          else
            nil
          end
      }

      case Chms.Church.WeekEndingReports
           |> Ash.Changeset.for_create(:create, report_attrs)
           |> Ash.create(authorize?: false) do
        {:ok, report} ->
          IO.puts("✓ Created report: #{report.report_name}")

          # Create category entries with random amounts
          Enum.each(all_categories, fn category ->
            # Generate amount based on category group
            # Some categories are more likely to have amounts
            amount =
              case category.group do
                :offerings ->
                  # Offerings are most common - 90% chance of having value
                  if Enum.random(1..10) <= 9 do
                    Decimal.new(Enum.random(100..3000))
                  else
                    Decimal.new(0)
                  end

                :ministries ->
                  # Ministries - 60% chance
                  if Enum.random(1..10) <= 6 do
                    Decimal.new(Enum.random(50..500))
                  else
                    Decimal.new(0)
                  end

                :missions ->
                  # Missions - 40% chance
                  if Enum.random(1..10) <= 4 do
                    Decimal.new(Enum.random(100..1000))
                  else
                    Decimal.new(0)
                  end

                :property ->
                  # Property - 30% chance
                  if Enum.random(1..10) <= 3 do
                    Decimal.new(Enum.random(200..2000))
                  else
                    Decimal.new(0)
                  end

                _ ->
                  # Custom - 20% chance
                  if Enum.random(1..10) <= 2 do
                    Decimal.new(Enum.random(25..250))
                  else
                    Decimal.new(0)
                  end
              end

            # Only create entry if amount > 0
            if Decimal.compare(amount, Decimal.new(0)) == :gt do
              entry_attrs = %{
                week_ending_report_id: report.id,
                report_category_id: category.id,
                amount: amount
              }

              case Chms.Church.ReportCategoryEntries
                   |> Ash.Changeset.for_create(:create, entry_attrs)
                   |> Ash.create(authorize?: false) do
                {:ok, _entry} ->
                  :ok

                {:error, _} ->
                  IO.puts("  ✗ Failed to create entry for #{category.display_name}")
              end
            end
          end)

        {:error, changeset} ->
          IO.puts("✗ Failed to create report for week ending #{week_end}")
          IO.inspect(changeset.errors)
      end
    end
  end)
end

IO.puts("\nSeeding complete!")

# Show overall statistics
total_congregants =
  case Chms.Church.Congregants
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, all_congregants} -> length(all_congregants)
    _ -> 0
  end

total_contributions =
  case Chms.Church.Contributions
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, all_contributions} -> length(all_contributions)
    _ -> 0
  end

total_ministry_funds =
  case Chms.Church.MinistryFunds
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, all_funds} -> length(all_funds)
    _ -> 0
  end

total_week_ending_reports =
  case Chms.Church.WeekEndingReports
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, all_reports} -> length(all_reports)
    _ -> 0
  end

# Count by status
status_counts =
  case Chms.Church.Congregants
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, all_congregants} ->
      all_congregants
      |> Enum.group_by(& &1.status)
      |> Enum.map(fn {status, list} -> {status, length(list)} end)
      |> Enum.into(%{})

    _ ->
      %{}
  end

# Count by country
country_counts =
  case Chms.Church.Congregants
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, all_congregants} ->
      all_congregants
      |> Enum.group_by(& &1.country)
      |> Enum.map(fn {country, list} -> {country, length(list)} end)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(10)

    _ ->
      []
  end

# Seed Events
IO.puts("\nSeeding events...")

# Check for existing events to avoid duplicates
existing_events =
  case Chms.Church.Events
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, events} -> events
    _ -> []
  end

if length(existing_events) > 0 do
  IO.puts("⊙ Events already exist, skipping seed")
else
  # Get current date info
  today = Date.utc_today()

  # Find next Sunday
  days_until_sunday = rem(7 - Date.day_of_week(today, :sunday), 7)
  days_until_sunday = if days_until_sunday == 0, do: 7, else: days_until_sunday
  next_sunday = Date.add(today, days_until_sunday)

  # Find next Wednesday
  days_until_wednesday = rem(3 - Date.day_of_week(today, :monday) + 7, 7)
  days_until_wednesday = if days_until_wednesday == 0, do: 7, else: days_until_wednesday
  next_wednesday = Date.add(today, days_until_wednesday)

  events_data = [
    # Regular Sunday Service (recurring)
    %{
      title: "Sunday Worship Service",
      description:
        "Join us for our weekly worship service with praise, prayer, and biblical teaching.",
      event_type: :service,
      start_time: DateTime.new!(next_sunday, ~T[10:00:00], "Etc/UTC"),
      end_time: DateTime.new!(next_sunday, ~T[12:00:00], "Etc/UTC"),
      all_day: false,
      location: "Main Sanctuary",
      is_recurring: true,
      recurrence_rule: "FREQ=WEEKLY;BYDAY=SU"
    },
    # Midweek Service (recurring)
    %{
      title: "Midweek Bible Study",
      description: "In-depth Bible study and prayer meeting. Come grow deeper in God's Word.",
      event_type: :midweek_service,
      start_time: DateTime.new!(next_wednesday, ~T[19:00:00], "Etc/UTC"),
      end_time: DateTime.new!(next_wednesday, ~T[20:30:00], "Etc/UTC"),
      all_day: false,
      location: "Fellowship Hall",
      is_recurring: true,
      recurrence_rule: "FREQ=WEEKLY;BYDAY=WE"
    },
    # Special Christmas Eve Service
    %{
      title: "Christmas Eve Candlelight Service",
      description:
        "A special candlelight service celebrating the birth of Jesus Christ. Bring your family for this meaningful Christmas tradition.",
      event_type: :special_service,
      start_time: DateTime.new!(~D[2025-12-24], ~T[18:00:00], "Etc/UTC"),
      end_time: DateTime.new!(~D[2025-12-24], ~T[19:30:00], "Etc/UTC"),
      all_day: false,
      location: "Main Sanctuary",
      is_recurring: false
    },
    # New Year's Eve Service
    %{
      title: "New Year's Eve Watch Night Service",
      description:
        "Ring in the new year with prayer, worship, and thanksgiving. Join us as we reflect on God's faithfulness.",
      event_type: :special_service,
      start_time: DateTime.new!(~D[2025-12-31], ~T[22:00:00], "Etc/UTC"),
      end_time: DateTime.new!(~D[2026-01-01], ~T[00:30:00], "Etc/UTC"),
      all_day: false,
      location: "Main Sanctuary",
      is_recurring: false
    },
    # Youth Friday Night
    %{
      title: "Youth Friday Night",
      description: "Fun, fellowship, and faith for teens. Games, worship, and relevant teaching.",
      event_type: :midweek_service,
      start_time:
        DateTime.new!(
          Date.add(today, rem(5 - Date.day_of_week(today, :monday) + 7, 7)),
          ~T[19:00:00],
          "Etc/UTC"
        ),
      end_time:
        DateTime.new!(
          Date.add(today, rem(5 - Date.day_of_week(today, :monday) + 7, 7)),
          ~T[21:00:00],
          "Etc/UTC"
        ),
      all_day: false,
      location: "Youth Center",
      is_recurring: true,
      recurrence_rule: "FREQ=WEEKLY;BYDAY=FR"
    },
    # Monthly Prayer Breakfast
    %{
      title: "Men's Prayer Breakfast",
      description: "Monthly gathering for men to fellowship over breakfast and pray together.",
      event_type: :special_service,
      start_time: DateTime.new!(Date.add(next_sunday, 7), ~T[07:30:00], "Etc/UTC"),
      end_time: DateTime.new!(Date.add(next_sunday, 7), ~T[09:00:00], "Etc/UTC"),
      all_day: false,
      location: "Fellowship Hall",
      is_recurring: true,
      recurrence_rule: "FREQ=MONTHLY;BYDAY=1SA"
    }
  ]

  Enum.each(events_data, fn attrs ->
    case Chms.Church.Events
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create(authorize?: false) do
      {:ok, event} ->
        recurring_text = if event.is_recurring, do: " (recurring)", else: ""
        IO.puts("✓ Created event: #{event.title}#{recurring_text}")

      {:error, changeset} ->
        IO.puts("✗ Failed to create event: #{attrs.title}")
        IO.inspect(changeset.errors)
    end
  end)
end

total_events =
  case Chms.Church.Events
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, all_events} -> length(all_events)
    _ -> 0
  end

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("DATABASE STATISTICS")
IO.puts(String.duplicate("=", 50))
IO.puts("Total congregants: #{total_congregants}")
IO.puts("Total contributions: #{total_contributions}")
IO.puts("Total ministry fund transactions: #{total_ministry_funds}")
IO.puts("Total week ending reports: #{total_week_ending_reports}")
IO.puts("Total events: #{total_events}")
IO.puts("\nCongregants by Status:")

Enum.each(status_counts, fn {status, count} ->
  IO.puts("  #{status}: #{count}")
end)

IO.puts("\nTop 10 Countries:")

Enum.each(country_counts, fn {country, count} ->
  IO.puts("  #{country}: #{count}")
end)

IO.puts(String.duplicate("=", 50))
