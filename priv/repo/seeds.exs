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

Enum.each(congregants, fn attrs ->
  case Chms.Church.Congregants
       |> Ash.Changeset.for_create(:create, attrs)
       |> Ash.create() do
    {:ok, congregant} ->
      IO.puts("✓ Created congregant: #{congregant.first_name} #{congregant.last_name} (ID: #{congregant.member_id})")

    {:error, changeset} ->
      IO.puts("✗ Failed to create congregant: #{attrs.first_name} #{attrs.last_name}")
      IO.inspect(changeset.errors)
  end
end)

IO.puts("\nSeeding complete!")
IO.puts("Total congregants created: #{length(congregants)}")
