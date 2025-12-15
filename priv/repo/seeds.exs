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

# Seed Family Relationship Types
IO.puts("\nSeeding family relationship types...")

family_relationship_types = [
  %{name: "father", display_name: "Father", inverse_name: "child", sort_order: 1},
  %{name: "mother", display_name: "Mother", inverse_name: "child", sort_order: 2},
  %{name: "son", display_name: "Son", inverse_name: "parent", sort_order: 3},
  %{name: "daughter", display_name: "Daughter", inverse_name: "parent", sort_order: 4},
  %{name: "spouse", display_name: "Spouse", inverse_name: "spouse", sort_order: 5},
  %{name: "brother", display_name: "Brother", inverse_name: "sibling", sort_order: 6},
  %{name: "sister", display_name: "Sister", inverse_name: "sibling", sort_order: 7},
  %{name: "grandfather", display_name: "Grandfather", inverse_name: "grandchild", sort_order: 8},
  %{name: "grandmother", display_name: "Grandmother", inverse_name: "grandchild", sort_order: 9},
  %{name: "grandson", display_name: "Grandson", inverse_name: "grandparent", sort_order: 10},
  %{
    name: "granddaughter",
    display_name: "Granddaughter",
    inverse_name: "grandparent",
    sort_order: 11
  },
  %{name: "uncle", display_name: "Uncle", inverse_name: "nephew_niece", sort_order: 12},
  %{name: "aunt", display_name: "Aunt", inverse_name: "nephew_niece", sort_order: 13},
  %{name: "nephew", display_name: "Nephew", inverse_name: "uncle_aunt", sort_order: 14},
  %{name: "niece", display_name: "Niece", inverse_name: "uncle_aunt", sort_order: 15},
  %{name: "cousin", display_name: "Cousin", inverse_name: "cousin", sort_order: 16}
]

existing_relationship_types =
  case Chms.Church.FamilyRelationshipType
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, types} -> types
    _ -> []
  end

if length(existing_relationship_types) > 0 do
  IO.puts("⊙ Family relationship types already exist, skipping seed")
else
  Enum.each(family_relationship_types, fn attrs ->
    case Chms.Church.FamilyRelationshipType
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create(authorize?: false) do
      {:ok, type} ->
        IO.puts("✓ Created family relationship type: #{type.display_name}")

      {:error, changeset} ->
        IO.puts("✗ Failed to create type: #{attrs.display_name}")
        IO.inspect(changeset.errors)
    end
  end)
end

# Seed Attendance Categories
IO.puts("\nSeeding attendance categories...")

# Check if attendance categories already exist
existing_attendance_categories =
  case Chms.Church.AttendanceCategories
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, categories} -> categories
    _ -> []
  end

if length(existing_attendance_categories) > 0 do
  IO.puts("⊙ Attendance categories already exist, skipping seed")
else
  # Get default attendance categories from the module
  default_attendance_categories = Chms.Church.AttendanceCategories.default_categories()

  Enum.each(default_attendance_categories, fn attrs ->
    attrs_with_active = Map.put(attrs, :active, true)

    case Chms.Church.AttendanceCategories
         |> Ash.Changeset.for_create(:create, attrs_with_active)
         |> Ash.create(authorize?: false) do
      {:ok, category} ->
        IO.puts("✓ Created attendance category: #{category.name} (#{category.color})")

      {:error, changeset} ->
        IO.puts("✗ Failed to create attendance category: #{attrs.name}")
        IO.inspect(changeset.errors)
    end
  end)
end

# Seed Attendance Sessions and Records
IO.puts("\nSeeding attendance sessions and records...")

# Get attendance categories
attendance_categories =
  case Chms.Church.AttendanceCategories
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, categories} -> categories
    _ -> []
  end

# Get all congregants for attendance records
all_congregants =
  case Chms.Church.Congregants
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, congregants} -> congregants
    _ -> []
  end

# Check for existing attendance sessions
existing_attendance_sessions =
  case Chms.Church.AttendanceSessions
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, sessions} -> sessions
    _ -> []
  end

if length(existing_attendance_sessions) > 0 do
  IO.puts("⊙ Attendance sessions already exist, skipping seed")
else
  if length(attendance_categories) == 0 do
    IO.puts("⊙ No attendance categories found, skipping attendance sessions seed")
  else
    if length(all_congregants) == 0 do
      IO.puts("⊙ No congregants found, skipping attendance sessions seed")
    else
      # Generate 20 attendance sessions over the last 60 days
      today = Date.utc_today()

      session_data =
        Enum.map(1..20, fn i ->
          # Pick a random category
          category = Enum.random(attendance_categories)

          # Generate a date within the last 60 days
          days_ago = Enum.random(0..60)
          session_date = Date.add(today, -days_ago)

          # Pick appropriate times based on category type
          {hour, minute} =
            cond do
              String.contains?(String.downcase(category.name), "service") or
                  String.contains?(String.downcase(category.name), "sunday") ->
                # Sunday services: morning times
                Enum.random([{9, 0}, {10, 0}, {11, 0}])

              String.contains?(String.downcase(category.name), "youth") ->
                # Youth: evening times
                Enum.random([{18, 0}, {19, 0}])

              String.contains?(String.downcase(category.name), "prayer") ->
                # Prayer: early morning or evening
                Enum.random([{6, 0}, {7, 0}, {19, 0}, {20, 0}])

              String.contains?(String.downcase(category.name), "bible") or
                  String.contains?(String.downcase(category.name), "study") ->
                # Bible study: evening
                Enum.random([{18, 30}, {19, 0}, {19, 30}])

              true ->
                # Default: various times
                Enum.random([{9, 0}, {10, 0}, {14, 0}, {18, 0}, {19, 0}])
            end

          session_datetime =
            DateTime.new!(session_date, Time.new!(hour, minute, 0), "Etc/UTC")

          # Random notes (40% chance)
          notes =
            if Enum.random(1..10) <= 4 do
              Enum.random([
                "Good attendance today",
                "Guest speaker present",
                "Special service",
                "Holiday weekend - lower attendance",
                "Communion Sunday",
                "Youth-led worship",
                "New members welcomed",
                "Birthday celebrations",
                "Anniversary service",
                "Normal service"
              ])
            else
              nil
            end

          %{
            category_id: category.id,
            session_datetime: session_datetime,
            notes: notes,
            # Will be updated after records are created
            total_present: 0,
            # Randomly select 5-30 congregants for this session
            attendees: Enum.take_random(all_congregants, Enum.random(5..min(30, length(all_congregants))))
          }
        end)

      # Create sessions and their attendance records
      Enum.with_index(session_data, 1)
      |> Enum.each(fn {session_attrs, index} ->
        attendees = session_attrs.attendees
        session_create_attrs = Map.drop(session_attrs, [:attendees, :total_present])

        case Chms.Church.AttendanceSessions
             |> Ash.Changeset.for_create(:create, session_create_attrs)
             |> Ash.create(authorize?: false) do
          {:ok, session} ->
            # Create attendance records for each attendee
            records_created =
              Enum.reduce(attendees, 0, fn congregant, count ->
                record_attrs = %{
                  session_id: session.id,
                  congregant_id: congregant.id,
                  present: true,
                  notes:
                    if Enum.random(1..10) == 1 do
                      Enum.random([
                        "First time visitor",
                        "Arrived late",
                        "Left early",
                        "Volunteered today",
                        "Brought a guest"
                      ])
                    else
                      nil
                    end
                }

                case Chms.Church.AttendanceRecords
                     |> Ash.Changeset.for_create(:create, record_attrs)
                     |> Ash.create(authorize?: false) do
                  {:ok, _record} -> count + 1
                  {:error, _} -> count
                end
              end)

            # Update the session with the total present count
            session
            |> Ash.Changeset.for_update(:update_total_present, %{total: records_created})
            |> Ash.update(authorize?: false)

            # Find category name for display
            category = Enum.find(attendance_categories, fn c -> c.id == session.category_id end)
            category_name = if category, do: category.name, else: "Unknown"

            IO.puts(
              "✓ Created session #{index}/20: #{category_name} on #{Date.to_string(DateTime.to_date(session.session_datetime))} with #{records_created} attendees"
            )

          {:error, changeset} ->
            IO.puts("✗ Failed to create attendance session #{index}")
            IO.inspect(changeset.errors)
        end
      end)
    end
  end
end

# Seed Service Attendance (Tuesdays, Fridays, Sundays - quantity only, no congregant records)
IO.puts("\nSeeding service attendance (50 sessions on Tue/Fri/Sun)...")

# Find the Services category
services_category =
  case Chms.Church.AttendanceCategories
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, categories} -> Enum.find(categories, fn c -> c.name == "Services" end)
    _ -> nil
  end

if is_nil(services_category) do
  IO.puts("⊙ Services category not found, skipping service attendance seed")
else
  # Check how many service sessions already exist
  existing_service_sessions =
    case Chms.Church.AttendanceSessions
         |> Ash.Query.for_read(:read)
         |> Ash.read(authorize?: false) do
      {:ok, sessions} -> Enum.filter(sessions, fn s -> s.category_id == services_category.id end)
      _ -> []
    end

  if length(existing_service_sessions) >= 50 do
    IO.puts("⊙ Service attendance sessions already exist (#{length(existing_service_sessions)}), skipping seed")
  else
    # Generate 50 service sessions on Tuesdays, Fridays, and Sundays
    today = Date.utc_today()

    # Service times based on day of week
    service_times = %{
      2 => ~T[19:00:00],  # Tuesday - 7 PM
      5 => ~T[19:30:00],  # Friday - 7:30 PM
      7 => ~T[10:00:00]   # Sunday - 10 AM
    }

    # Service notes
    service_notes = [
      "Regular service",
      "Good attendance",
      "Special prayer service",
      "Guest speaker",
      "Communion service",
      "Youth-led worship",
      "Anniversary celebration",
      nil,
      nil,
      nil
    ]

    # Generate dates for Tuesdays (2), Fridays (5), and Sundays (7) going back
    # We need 50 sessions, so roughly 17 weeks back (3 services per week)
    service_dates =
      0..120
      |> Enum.map(fn days_back -> Date.add(today, -days_back) end)
      |> Enum.filter(fn date ->
        day_of_week = Date.day_of_week(date)
        day_of_week in [2, 5, 7]  # Tuesday, Friday, Sunday
      end)
      |> Enum.take(50)

    Enum.with_index(service_dates, 1)
    |> Enum.each(fn {date, index} ->
      day_of_week = Date.day_of_week(date)
      time = Map.get(service_times, day_of_week, ~T[10:00:00])
      session_datetime = DateTime.new!(date, time, "Etc/UTC")

      # Random attendance between 45 and 150
      attendance = Enum.random(45..150)

      # Random notes
      notes = Enum.random(service_notes)

      session_attrs = %{
        category_id: services_category.id,
        session_datetime: session_datetime,
        notes: notes
      }

      case Chms.Church.AttendanceSessions
           |> Ash.Changeset.for_create(:create, session_attrs)
           |> Ash.create(authorize?: false) do
        {:ok, session} ->
          # Update the total_present count
          session
          |> Ash.Changeset.for_update(:update_total_present, %{total: attendance})
          |> Ash.update(authorize?: false)

          day_name = Calendar.strftime(date, "%A")
          IO.puts("✓ Service #{index}/50: #{day_name} #{Date.to_string(date)} at #{Time.to_string(time)} - #{attendance} attendees")

        {:error, changeset} ->
          IO.puts("✗ Failed to create service session #{index}")
          IO.inspect(changeset.errors)
      end
    end)
  end
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
  # In Elixir, Date.day_of_week returns 1-7 where 1=Monday, 7=Sunday
  current_day_of_week = Date.day_of_week(today)
  days_since_sunday = if current_day_of_week == 7, do: 0, else: current_day_of_week
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

# Helper function to get day of week abbreviation
get_day_of_week = fn date ->
  case Date.day_of_week(date) do
    1 -> "MO"
    2 -> "TU"
    3 -> "WE"
    4 -> "TH"
    5 -> "FR"
    6 -> "SA"
    7 -> "SU"
  end
end

# Function to generate events for December 2025 through May 2026 (8 events per month)
generate_events_for_months = fn ->
  # Event templates with different types
  event_templates = [
    %{
      title: "Community Outreach",
      description:
        "Serving the local community through various outreach programs and activities.",
      locations: ["Community Center", "Local Park", "Downtown Area"],
      colors: ["#10b981", "#059669", "#047857"],
      time_ranges: [{9, 12}, {14, 17}, {10, 13}]
    },
    %{
      title: "Prayer Meeting",
      description: "A time of dedicated prayer for our church, community, and world.",
      locations: ["Prayer Room", "Main Sanctuary", "Fellowship Hall"],
      colors: ["#7c3aed", "#6d28d9", "#5b21b6"],
      time_ranges: [{18, 19}, {19, 20}, {7, 8}]
    },
    %{
      title: "Worship Team Practice",
      description: "Practice session for the worship team to prepare for upcoming services.",
      locations: ["Main Sanctuary", "Rehearsal Room"],
      colors: ["#f59e0b", "#d97706", "#b45309"],
      time_ranges: [{19, 21}, {18, 20}, {20, 22}]
    },
    %{
      title: "Bible Study Group",
      description: "Small group Bible study for deeper understanding of Scripture.",
      locations: ["Fellowship Hall", "Classroom A", "Library"],
      colors: ["#0891b2", "#0e7490", "#155e75"],
      time_ranges: [{19, 20}, {10, 11}, {14, 15}]
    },
    %{
      title: "Youth Fellowship",
      description: "Fun activities and spiritual growth for young people.",
      locations: ["Youth Center", "Gym", "Fellowship Hall"],
      colors: ["#ec4899", "#db2777", "#be185d"],
      time_ranges: [{18, 20}, {19, 21}, {15, 17}]
    },
    %{
      title: "Seniors Luncheon",
      description: "Monthly gathering for senior members to fellowship over lunch.",
      locations: ["Fellowship Hall", "Community Room"],
      colors: ["#6b7280", "#4b5563", "#374151"],
      time_ranges: [{12, 14}, {11, 13}]
    },
    %{
      title: "Mission Planning Meeting",
      description: "Planning session for upcoming mission trips and outreach activities.",
      locations: ["Conference Room", "Library", "Office"],
      colors: ["#dc2626", "#b91c1c", "#991b1b"],
      time_ranges: [{19, 21}, {18, 20}, {14, 16}]
    },
    %{
      title: "Family Fun Day",
      description: "A day of fun activities for the whole family to enjoy together.",
      locations: ["Church Grounds", "Local Park", "Community Center"],
      colors: ["#16a34a", "#15803d", "#166534"],
      time_ranges: [{10, 16}, {11, 17}, {9, 15}]
    },
    %{
      title: "Women's Ministry Meeting",
      description: "Monthly gathering for women to fellowship and grow together in faith.",
      locations: ["Fellowship Hall", "Women's Room", "Library"],
      colors: ["#f472b6", "#ec4899", "#db2777"],
      time_ranges: [{10, 12}, {18, 20}, {14, 16}]
    },
    %{
      title: "Men's Breakfast",
      description: "Monthly breakfast and fellowship for men of the church.",
      locations: ["Fellowship Hall", "Cafeteria"],
      colors: ["#0284c7", "#0369a1", "#075985"],
      time_ranges: [{7, 9}, {8, 10}]
    },
    %{
      title: "Choir Practice",
      description: "Weekly choir rehearsal for upcoming services and special events.",
      locations: ["Choir Room", "Main Sanctuary"],
      colors: ["#8b5cf6", "#7c3aed", "#6d28d9"],
      time_ranges: [{18, 20}, {19, 21}]
    },
    %{
      title: "Children's Ministry",
      description: "Fun and educational activities for children to learn about God's love.",
      locations: ["Children's Wing", "Classroom B", "Playground"],
      colors: ["#f97316", "#ea580c", "#c2410c"],
      time_ranges: [{10, 12}, {14, 16}]
    }
  ]

  # Define months to generate events for (December 2025 through May 2026)
  months = [
    # December 2025
    {2025, 12},
    # January 2026
    {2026, 1},
    # February 2026
    {2026, 2},
    # March 2026
    {2026, 3},
    # April 2026
    {2026, 4},
    # May 2026
    {2026, 5}
  ]

  # Generate 8 events per month
  Enum.flat_map(months, fn {year, month} ->
    days_in_month = Date.days_in_month(Date.new!(year, month, 1))

    # Generate 8 random days spread across the month (avoiding day 1 to not conflict with recurring events)
    available_days = 2..days_in_month |> Enum.to_list()
    selected_days = Enum.take_random(available_days, 8)

    Enum.map(selected_days, fn day ->
      date = Date.new!(year, month, day)
      template = Enum.random(event_templates)
      location = Enum.random(template.locations)
      color = Enum.random(template.colors)
      {start_hour, end_hour} = Enum.random(template.time_ranges)

      # Create some recurring events (30% chance)
      is_recurring = Enum.random(1..10) <= 3

      recurrence_rule =
        if is_recurring do
          case Enum.random(1..3) do
            1 -> "FREQ=WEEKLY;BYDAY=#{get_day_of_week.(date)}"
            2 -> "FREQ=MONTHLY;BYMONTHDAY=#{date.day}"
            3 -> "FREQ=WEEKLY;INTERVAL=2;BYDAY=#{get_day_of_week.(date)}"
          end
        else
          nil
        end

      %{
        title: template.title,
        description: template.description,
        start_time: DateTime.new!(date, Time.new!(start_hour, 0, 0), "Etc/UTC"),
        end_time: DateTime.new!(date, Time.new!(end_hour, 0, 0), "Etc/UTC"),
        all_day: false,
        location: location,
        color: color,
        is_recurring: is_recurring,
        recurrence_rule: recurrence_rule
      }
    end)
  end)
end

# Check for existing events
existing_events =
  case Chms.Church.Events
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, events} -> events
    _ -> []
  end

# Always seed base events if none exist, then add monthly events
if length(existing_events) > 0 do
  IO.puts(
    "⊙ Base events already exist, adding monthly events (8 per month, Dec 2025 - May 2026)..."
  )

  # Generate events for each month (8 per month)
  monthly_events = generate_events_for_months.()

  Enum.each(monthly_events, fn attrs ->
    case Chms.Church.Events
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create(authorize?: false) do
      {:ok, event} ->
        recurring_text = if event.is_recurring, do: " (recurring)", else: ""

        IO.puts(
          "✓ Created event: #{event.title} on #{Date.to_string(DateTime.to_date(event.start_time))}#{recurring_text}"
        )

      {:error, changeset} ->
        IO.puts("✗ Failed to create event: #{attrs.title}")
        IO.inspect(changeset.errors)
    end
  end)
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
      start_time: DateTime.new!(next_sunday, ~T[10:00:00], "Etc/UTC"),
      end_time: DateTime.new!(next_sunday, ~T[12:00:00], "Etc/UTC"),
      all_day: false,
      location: "Main Sanctuary",
      color: "#06b6d4",
      is_recurring: true,
      recurrence_rule: "FREQ=WEEKLY;BYDAY=SU"
    },
    # Midweek Service (recurring)
    %{
      title: "Midweek Bible Study",
      description: "In-depth Bible study and prayer meeting. Come grow deeper in God's Word.",
      start_time: DateTime.new!(next_wednesday, ~T[19:00:00], "Etc/UTC"),
      end_time: DateTime.new!(next_wednesday, ~T[20:30:00], "Etc/UTC"),
      all_day: false,
      location: "Fellowship Hall",
      color: "#10b981",
      is_recurring: true,
      recurrence_rule: "FREQ=WEEKLY;BYDAY=WE"
    },
    # Special Christmas Eve Service
    %{
      title: "Christmas Eve Candlelight Service",
      description:
        "A special candlelight service celebrating the birth of Jesus Christ. Bring your family for this meaningful Christmas tradition.",
      start_time: DateTime.new!(~D[2025-12-24], ~T[18:00:00], "Etc/UTC"),
      end_time: DateTime.new!(~D[2025-12-24], ~T[19:30:00], "Etc/UTC"),
      all_day: false,
      location: "Main Sanctuary",
      color: "#dc2626",
      is_recurring: false
    },
    # New Year's Eve Service
    %{
      title: "New Year's Eve Watch Night Service",
      description:
        "Ring in the new year with prayer, worship, and thanksgiving. Join us as we reflect on God's faithfulness.",
      start_time: DateTime.new!(~D[2025-12-31], ~T[22:00:00], "Etc/UTC"),
      end_time: DateTime.new!(~D[2026-01-01], ~T[00:30:00], "Etc/UTC"),
      all_day: false,
      location: "Main Sanctuary",
      color: "#7c3aed",
      is_recurring: false
    },
    # Youth Friday Night
    %{
      title: "Youth Friday Night",
      description: "Fun, fellowship, and faith for teens. Games, worship, and relevant teaching.",
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
      color: "#f59e0b",
      is_recurring: true,
      recurrence_rule: "FREQ=WEEKLY;BYDAY=FR"
    },
    # Monthly Prayer Breakfast
    %{
      title: "Men's Prayer Breakfast",
      description: "Monthly gathering for men to fellowship over breakfast and pray together.",
      start_time: DateTime.new!(Date.add(next_sunday, 7), ~T[07:30:00], "Etc/UTC"),
      end_time: DateTime.new!(Date.add(next_sunday, 7), ~T[09:00:00], "Etc/UTC"),
      all_day: false,
      location: "Fellowship Hall",
      color: "#0891b2",
      is_recurring: true,
      recurrence_rule: "FREQ=MONTHLY;BYDAY=1SA"
    }
  ]

  # Generate additional events for December 2025 through May 2026 (8 per month)
  additional_events = generate_events_for_months.()

  all_events = events_data ++ additional_events

  Enum.each(all_events, fn attrs ->
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

total_attendance_categories =
  case Chms.Church.AttendanceCategories
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, all_categories} -> length(all_categories)
    _ -> 0
  end

total_attendance_sessions =
  case Chms.Church.AttendanceSessions
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, all_sessions} -> length(all_sessions)
    _ -> 0
  end

total_attendance_records =
  case Chms.Church.AttendanceRecords
       |> Ash.Query.for_read(:read)
       |> Ash.read(authorize?: false) do
    {:ok, all_records} -> length(all_records)
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
IO.puts("Total attendance categories: #{total_attendance_categories}")
IO.puts("Total attendance sessions: #{total_attendance_sessions}")
IO.puts("Total attendance records: #{total_attendance_records}")
IO.puts("\nCongregants by Status:")

Enum.each(status_counts, fn {status, count} ->
  IO.puts("  #{status}: #{count}")
end)

IO.puts("\nTop 10 Countries:")

Enum.each(country_counts, fn {country, count} ->
  IO.puts("  #{country}: #{count}")
end)

IO.puts(String.duplicate("=", 50))
