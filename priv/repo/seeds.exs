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
    member_id: 1_000_001,
    first_name: "John",
    last_name: "Smith",
    address: "123 Main St",
    city: "Springfield",
    state: "IL",
    zip_code: "62701",
    country: "USA",
    mobile_tel: "555-0101",
    home_tel: "555-0102",
    dob: ~D[1980-05-15],
    member_since: ~D[2020-01-15],
    status: :member,
    is_leader: true
  },
  %{
    member_id: 1_000_002,
    first_name: "Mary",
    last_name: "Johnson",
    address: "456 Oak Ave",
    city: "Springfield",
    state: "IL",
    zip_code: "62702",
    country: "USA",
    mobile_tel: "555-0201",
    dob: ~D[1985-08-22],
    member_since: ~D[2019-06-10],
    status: :member,
    is_leader: false
  },
  %{
    member_id: 1_000_003,
    first_name: "Robert",
    last_name: "Williams",
    address: "789 Elm Street",
    city: "Springfield",
    state: "IL",
    zip_code: "62703",
    country: "USA",
    mobile_tel: "555-0301",
    work_tel: "555-0302",
    dob: ~D[1975-03-10],
    member_since: ~D[2018-03-20],
    status: :member,
    is_leader: true
  },
  %{
    member_id: 1_000_004,
    first_name: "Patricia",
    last_name: "Brown",
    address: "321 Pine Rd",
    city: "Springfield",
    state: "IL",
    zip_code: "62704",
    country: "USA",
    mobile_tel: "555-0401",
    dob: ~D[1990-11-05],
    member_since: ~D[2021-09-15],
    status: :member,
    is_leader: false
  },
  %{
    member_id: 1_000_005,
    first_name: "Michael",
    last_name: "Davis",
    address: "654 Maple Dr",
    city: "Springfield",
    state: "IL",
    zip_code: "62705",
    country: "USA",
    mobile_tel: "555-0501",
    home_tel: "555-0502",
    dob: ~D[1988-07-18],
    member_since: ~D[2022-02-28],
    status: :visitor,
    is_leader: false
  },
  %{
    member_id: 1_000_006,
    first_name: "Jennifer",
    last_name: "Miller",
    address: "987 Cedar Ln",
    city: "Springfield",
    state: "IL",
    zip_code: "62706",
    country: "USA",
    mobile_tel: "555-0601",
    dob: ~D[1982-12-30],
    member_since: ~D[2017-11-05],
    status: :member,
    is_leader: true
  },
  %{
    member_id: 1_000_007,
    first_name: "David",
    last_name: "Wilson",
    address: "147 Birch Way",
    city: "Springfield",
    state: "IL",
    zip_code: "62707",
    country: "USA",
    mobile_tel: "555-0701",
    dob: ~D[1992-04-25],
    member_since: ~D[2023-01-10],
    status: :visitor,
    is_leader: false
  },
  %{
    member_id: 1_000_008,
    first_name: "Linda",
    last_name: "Moore",
    address: "258 Spruce Ct",
    city: "Springfield",
    state: "IL",
    zip_code: "62708",
    country: "USA",
    mobile_tel: "555-0801",
    home_tel: "555-0802",
    dob: ~D[1978-09-12],
    member_since: ~D[2016-07-20],
    status: :member,
    is_leader: false
  },
  %{
    member_id: 1_000_009,
    first_name: "James",
    last_name: "Taylor",
    address: "369 Willow Blvd",
    city: "Springfield",
    state: "IL",
    zip_code: "62709",
    country: "USA",
    mobile_tel: "555-0901",
    work_tel: "555-0902",
    dob: ~D[1986-01-08],
    member_since: ~D[2019-12-15],
    status: :member,
    is_leader: true
  },
  %{
    member_id: 1_000_010,
    first_name: "Barbara",
    last_name: "Anderson",
    address: "741 Ash Ave",
    city: "Springfield",
    state: "IL",
    zip_code: "62710",
    country: "USA",
    mobile_tel: "555-1001",
    dob: ~D[1995-06-20],
    member_since: ~D[2023-05-01],
    status: :visitor,
    is_leader: false
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
