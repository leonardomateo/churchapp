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
countries =
  List.duplicate("Dominican Republic", 5) ++  # 5x weight for Dominican Republic
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
  "Juan", "Maria", "Jose", "Ana", "Carlos", "Carmen", "Luis", "Rosa", "Miguel", "Isabel",
  "Pedro", "Sofia", "Jorge", "Elena", "Francisco", "Laura", "Antonio", "Patricia", "Manuel", "Teresa",
  "Rafael", "Lucia", "Fernando", "Gabriela", "Roberto", "Valentina", "Diego", "Camila", "Alejandro", "Andrea",
  "Ricardo", "Monica", "Javier", "Daniela", "Sergio", "Natalia", "Pablo", "Victoria", "Andres", "Mariana",
  "Raul", "Adriana", "Oscar", "Beatriz", "Enrique", "Claudia", "Hector", "Silvia", "Arturo", "Veronica",
  "Gustavo", "Paola", "Eduardo", "Cristina", "Alberto", "Sandra", "Julio", "Diana", "Cesar", "Alejandra",
  "Felipe", "Lorena", "Rodrigo", "Angelica", "Mauricio", "Fernanda", "Ernesto", "Juliana", "Armando", "Carolina",
  "Victor", "Marcela", "Ramon", "Susana", "Guillermo", "Yolanda", "Ruben", "Cecilia", "Ignacio", "Alicia"
]

# Common Latin American last names
last_names = [
  "Garcia", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Perez", "Sanchez", "Ramirez", "Torres",
  "Flores", "Rivera", "Gomez", "Diaz", "Cruz", "Morales", "Reyes", "Gutierrez", "Ortiz", "Chavez",
  "Ruiz", "Jimenez", "Mendoza", "Alvarez", "Castillo", "Romero", "Herrera", "Medina", "Aguilar", "Vargas",
  "Castro", "Ramos", "Moreno", "Guerrero", "Mendez", "Rojas", "Delgado", "Campos", "Vazquez", "Nunez",
  "Soto", "Contreras", "Luna", "Rios", "Mejia", "Dominguez", "Guzman", "Velasquez", "Salazar", "Pena"
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
    {city, state} = case country do
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
    days_member = Enum.random(365..3650)  # 1-10 years
    member_since = Date.add(Date.utc_today(), -days_member)

    days_old = Enum.random(6570..25550)  # 18-70 years old
    dob = Date.add(Date.utc_today(), -days_old)

    %{
      first_name: Enum.random(first_names),
      last_name: Enum.random(last_names),
      address: "#{Enum.random(100..9999)} #{Enum.random(["Main", "Oak", "Maple", "Pine", "Elm"])} #{Enum.random(["St", "Ave", "Blvd", "Dr", "Ln"])}",
      suite: if(Enum.random(1..3) == 1, do: "Apt #{Enum.random(1..20)}", else: nil),
      city: city,
      state: state,
      zip_code: "#{Enum.random(10000..99999)}",
      country: country,
      mobile_tel: "(#{Enum.random(200..999)}) #{Enum.random(200..999)}-#{Enum.random(1000..9999)}",
      home_tel: if(Enum.random(1..3) == 1, do: "(#{Enum.random(200..999)}) #{Enum.random(200..999)}-#{Enum.random(1000..9999)}", else: nil),
      work_tel: if(Enum.random(1..4) == 1, do: "(#{Enum.random(200..999)}) #{Enum.random(200..999)}-#{Enum.random(1000..9999)}", else: nil),
      dob: dob,
      member_since: member_since,
      status: status,
      is_leader: Enum.random(1..5) == 1,  # 20% are leaders
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
        IO.puts(
          "⊙ Congregant already exists: #{congregant.first_name} #{congregant.last_name}"
        )

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

IO.puts(
  "Creating contributions for #{length(newly_created_congregants)} congregants..."
)

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
      IO.puts(
        "✗ Failed to create contribution: #{attrs.contribution_type}"
      )

      IO.inspect(changeset.errors)
  end
end)

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
    _ -> %{}
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
    _ -> []
  end

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("DATABASE STATISTICS")
IO.puts(String.duplicate("=", 50))
IO.puts("Total congregants: #{total_congregants}")
IO.puts("Total contributions: #{total_contributions}")
IO.puts("\nCongregants by Status:")
Enum.each(status_counts, fn {status, count} ->
  IO.puts("  #{status}: #{count}")
end)
IO.puts("\nTop 10 Countries:")
Enum.each(country_counts, fn {country, count} ->
  IO.puts("  #{country}: #{count}")
end)
IO.puts(String.duplicate("=", 50))
