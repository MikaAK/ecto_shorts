# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     EctoShorts.Repo.insert!(%EctoShorts.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias EctoShorts.Repo
alias EctoShorts.Schema.{User, Post, Comment}

Repo.start_link()

# Create users
users = [
  %User{
    first_name: "John",
    last_name: "Doe",
    age: 28,
    email: "john.doe@example.com"
  },
  %User{
    first_name: "Jane",
    last_name: "Smith",
    age: 32,
    email: "jane.smith@example.com"
  },
  %User{
    first_name: "Bob",
    last_name: "Johnson",
    age: 45,
    email: "bob.johnson@example.com"
  }
]

inserted_users = Enum.map(users, fn user ->
  Repo.insert!(user)
end)

# Create posts
posts = [
  %Post{
    title: "Getting started with Elixir",
    body: "Elixir is a functional programming language designed for building scalable and maintainable applications.",
    permalink: "getting-started-elixir",
    published: true,
    published_at: ~U[2024-01-20 10:00:00Z], # 1 day ago
    tags: ["elixir", "programming", "tutorial"],
    views: 1250,
    author_id: Enum.at(inserted_users, 0).id
  },
  %Post{
    title: "Understanding Ecto Changesets",
    body: "Changesets are the primary way to work with data in Ecto, providing validation and casting functionality.",
    permalink: "understanding-ecto-changesets",
    published: true,
    published_at: ~U[2024-01-19 10:00:00Z], # 2 days ago
    tags: ["ecto", "elixir", "database"],
    views: 890,
    author_id: Enum.at(inserted_users, 1).id
  },
  %Post{
    title: "Phoenix Framework Overview",
    body: "Phoenix is a web framework built on Elixir that provides productivity and performance.",
    permalink: "phoenix-framework-overview",
    published: false,
    tags: ["phoenix", "web", "elixir"],
    views: 567,
    author_id: Enum.at(inserted_users, 2).id
  },
  %Post{
    title: "Functional Programming Concepts",
    body: "Learn about the core concepts of functional programming and how they apply to Elixir.",
    permalink: "functional-programming-concepts",
    published: true,
    published_at: ~U[2024-01-18 10:00:00Z], # 3 days ago
    tags: ["functional", "programming", "concepts"],
    views: 2100,
    author_id: Enum.at(inserted_users, 0).id
  }
]

inserted_posts = Enum.map(posts, fn post ->
  Repo.insert!(post)
end)

# Create comments
comments = [
  %Comment{
    body: "Great article! This really helped me understand Elixir better.",
    published: true,
    published_at: ~N[2024-01-21 09:00:00], # 1 hour ago
    replies: 2,
    tags: ["helpful", "beginner"],
    author_id: Enum.at(inserted_users, 1).id,
    post_id: Enum.at(inserted_posts, 0).id
  },
  %Comment{
    body: "I think you should add more examples about pattern matching.",
    published: true,
    published_at: ~N[2024-01-21 08:00:00], # 2 hours ago
    replies: 0,
    tags: ["feedback", "suggestion"],
    author_id: Enum.at(inserted_users, 2).id,
    post_id: Enum.at(inserted_posts, 0).id
  },
  %Comment{
    body: "The explanation of changesets is very clear. Thanks for sharing!",
    published: true,
    published_at: ~N[2024-01-21 07:00:00], # 3 hours ago
    replies: 1,
    tags: ["changesets", "ecto"],
    author_id: Enum.at(inserted_users, 0).id,
    post_id: Enum.at(inserted_posts, 1).id
  },
  %Comment{
    body: "When will the Phoenix article be published? Looking forward to it!",
    published: true,
    published_at: ~N[2024-01-21 06:00:00], # 4 hours ago
    replies: 3,
    tags: ["question", "phoenix"],
    author_id: Enum.at(inserted_users, 1).id,
    post_id: Enum.at(inserted_posts, 2).id
  },
  %Comment{
    body: "Functional programming concepts can be tricky at first, but this explanation makes it much easier.",
    published: true,
    published_at: ~N[2024-01-21 05:00:00], # 5 hours ago
    replies: 1,
    tags: ["functional", "learning"],
    author_id: Enum.at(inserted_users, 2).id,
    post_id: Enum.at(inserted_posts, 3).id
  },
  %Comment{
    body: "This is a draft comment that shouldn't be visible yet.",
    published: false,
    replies: 0,
    tags: ["draft"],
    author_id: Enum.at(inserted_users, 0).id,
    post_id: Enum.at(inserted_posts, 3).id
  }
]

Enum.each(comments, fn comment ->
  Repo.insert!(comment)
end)

IO.puts("Database seeded successfully!")
IO.puts("Created #{length(inserted_users)} users")
IO.puts("Created #{length(inserted_posts)} posts")
IO.puts("Created #{length(comments)} comments")
