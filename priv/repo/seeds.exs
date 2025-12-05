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
IO.puts("Seeding congregants...")

congregants = [
  %{
    first_name: "Jennifer",
    last_name: "Miller",
    address: "555 Oak Avenue",
    city: "Brooklyn",
    state: "New York",
    zip_code: "11220",
    country: "USA",
    mobile_tel: "(555) 123-4567",
    home_tel: "(555) 123-4568",
    dob: ~D[1985-03-15],
    member_since: ~D[2017-11-05],
    status: :member,
    is_leader: true
  },
  %{
    first_name: "John",
    last_name: "Smith",
    address: "789 Pine Street",
    suite: "Apt 4B",
    city: "Manhattan",
    state: "New York",
    zip_code: "10001",
    country: "USA",
    mobile_tel: "(555) 234-5678",
    work_tel: "(555) 234-5679",
    dob: ~D[1978-07-22],
    member_since: ~D[2015-01-15],
    status: :member,
    is_leader: true
  },
  %{
    first_name: "Maria",
    last_name: "Garcia",
    address: "321 Elm Drive",
    city: "Queens",
    state: "New York",
    zip_code: "11375",
    country: "USA",
    mobile_tel: "(555) 345-6789",
    dob: ~D[1992-12-08],
    member_since: ~D[2020-06-10],
    status: :member,
    is_leader: false
  },
  %{
    first_name: "Michael",
    last_name: "Johnson",
    address: "987 Maple Lane",
    suite: "Unit 12",
    city: "Bronx",
    state: "New York",
    zip_code: "10451",
    country: "USA",
    mobile_tel: "(555) 456-7890",
    home_tel: "(555) 456-7891",
    dob: ~D[1988-05-30],
    member_since: ~D[2019-03-20],
    status: :member,
    is_leader: true
  },
  %{
    first_name: "Sarah",
    last_name: "Williams",
    address: "147 Cedar Court",
    city: "Brooklyn",
    state: "New York",
    zip_code: "11201",
    country: "USA",
    mobile_tel: "(555) 567-8901",
    dob: ~D[1995-09-14],
    member_since: ~D[2022-08-15],
    status: :visitor,
    is_leader: false
  },
  %{
    first_name: "David",
    last_name: "Brown",
    address: "852 Birch Boulevard",
    city: "Staten Island",
    state: "New York",
    zip_code: "10301",
    country: "USA",
    mobile_tel: "(555) 678-9012",
    work_tel: "(555) 678-9013",
    dob: ~D[1982-11-25],
    member_since: ~D[2016-05-01],
    status: :member,
    is_leader: false
  },
  %{
    first_name: "Lisa",
    last_name: "Davis",
    address: "963 Willow Way",
    suite: "Apt 3C",
    city: "Manhattan",
    state: "New York",
    zip_code: "10002",
    country: "USA",
    mobile_tel: "(555) 789-0123",
    dob: ~D[1990-04-18],
    member_since: ~D[2021-02-28],
    status: :member,
    is_leader: true
  },
  %{
    first_name: "Robert",
    last_name: "Martinez",
    address: "258 Spruce Street",
    city: "Queens",
    state: "New York",
    zip_code: "11385",
    country: "USA",
    mobile_tel: "(555) 890-1234",
    home_tel: "(555) 890-1235",
    dob: ~D[1975-08-07],
    member_since: ~D[2014-09-12],
    status: :member,
    is_leader: true
  },
  %{
    first_name: "Emily",
    last_name: "Rodriguez",
    address: "741 Ash Avenue",
    city: "Brooklyn",
    state: "New York",
    zip_code: "11215",
    country: "USA",
    mobile_tel: "(555) 901-2345",
    dob: ~D[1998-01-29],
    member_since: ~D[2023-04-10],
    status: :visitor,
    is_leader: false
  },
  %{
    first_name: "James",
    last_name: "Wilson",
    address: "369 Poplar Place",
    suite: "Suite 5",
    city: "Bronx",
    state: "New York",
    zip_code: "10468",
    country: "USA",
    mobile_tel: "(555) 012-3456",
    work_tel: "(555) 012-3457",
    dob: ~D[1987-06-11],
    member_since: ~D[2018-12-05],
    status: :member,
    is_leader: false
  },
  %{
    first_name: "Amanda",
    last_name: "Taylor",
    address: "456 Hickory Hill",
    city: "Staten Island",
    state: "New York",
    zip_code: "10314",
    country: "USA",
    mobile_tel: "(555) 123-4560",
    dob: ~D[1993-10-03],
    member_since: ~D[2020-11-20],
    status: :member,
    is_leader: false
  },
  %{
    first_name: "Christopher",
    last_name: "Anderson",
    address: "789 Magnolia Drive",
    city: "Manhattan",
    state: "New York",
    zip_code: "10003",
    country: "USA",
    mobile_tel: "(555) 234-5671",
    home_tel: "(555) 234-5672",
    work_tel: "(555) 234-5673",
    dob: ~D[1980-02-17],
    member_since: ~D[2015-07-08],
    status: :member,
    is_leader: true
  },
  %{
    first_name: "Jessica",
    last_name: "Thomas",
    address: "147 Dogwood Lane",
    suite: "Apt 2A",
    city: "Queens",
    state: "New York",
    zip_code: "11354",
    country: "USA",
    mobile_tel: "(555) 345-6782",
    dob: ~D[1991-12-21],
    member_since: ~D[2019-08-30],
    status: :member,
    is_leader: false
  },
  %{
    first_name: "Daniel",
    last_name: "Jackson",
    address: "951 Sycamore Street",
    city: "Brooklyn",
    state: "New York",
    zip_code: "11226",
    country: "USA",
    mobile_tel: "(555) 456-7893",
    dob: ~D[1996-05-09],
    member_since: ~D[2023-01-15],
    status: :visitor,
    is_leader: false
  },
  %{
    first_name: "Michelle",
    last_name: "White",
    address: "753 Chestnut Circle",
    city: "Bronx",
    state: "New York",
    zip_code: "10475",
    country: "USA",
    mobile_tel: "(555) 567-8904",
    home_tel: "(555) 567-8905",
    dob: ~D[1984-09-26],
    member_since: ~D[2017-03-22],
    status: :member,
    is_leader: true
  }
]

created_congregants =
  Enum.map(congregants, fn attrs ->
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
              "✓ Created congregant: #{congregant.first_name} #{congregant.last_name} (ID: #{congregant.member_id})"
            )

            congregant

          {:error, changeset} ->
            IO.puts("✗ Failed to create congregant: #{attrs.first_name} #{attrs.last_name}")
            IO.inspect(changeset.errors)
            nil
        end

      {:ok, congregant} ->
        IO.puts(
          "⊙ Congregant already exists: #{congregant.first_name} #{congregant.last_name} (ID: #{congregant.member_id})"
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
IO.puts("\nSeeding contributions...")

# Contribution types to use
contribution_types = [
  "Tithes",
  "General Offering",
  "Mission",
  "Building Fund",
  "Special Offering"
]

# Only create contributions for newly created congregants to avoid duplicates
# Filter out congregants that already existed
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
  "Creating contributions for #{length(newly_created_congregants)} congregants (skipping #{length(created_congregants) - length(newly_created_congregants)} that already have contributions)..."
)

# Generate contributions for each congregant
contributions =
  newly_created_congregants
  |> Enum.flat_map(fn congregant ->
    # Generate 3-8 random contributions per congregant
    num_contributions = Enum.random(3..8)

    Enum.map(1..num_contributions, fn _ ->
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

      # Random amount between $10 and $500
      amount = Decimal.new(Enum.random(10..500))

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
            "Thanksgiving offering"
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
  end)

Enum.each(contributions, fn attrs ->
  case Chms.Church.Contributions
       |> Ash.Changeset.for_create(:create, attrs)
       |> Ash.create(authorize?: false) do
    {:ok, contribution} ->
      IO.puts(
        "✓ Created contribution: #{contribution.contribution_type} - $#{Decimal.to_string(contribution.revenue, :normal)} on #{Calendar.strftime(contribution.contribution_date, "%b %d, %Y at %I:%M %p")}"
      )

    {:error, changeset} ->
      IO.puts(
        "✗ Failed to create contribution: #{attrs.contribution_type} - #{attrs.contribution_date}"
      )

      IO.inspect(changeset.errors)
  end
end)

IO.puts("\nSeeding complete!")
IO.puts("Total congregants available: #{length(created_congregants)}")
IO.puts("Total contributions created: #{length(contributions)}")

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

IO.puts("\n--- Database Totals ---")
IO.puts("Total congregants in database: #{total_congregants}")
IO.puts("Total contributions in database: #{total_contributions}")
