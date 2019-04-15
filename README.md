# Arevel

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix


Server setup
ulimit -n 200000
Set min heap space to be a bit larger. Maybe between 1 and 6kb? 6 kb sounds nice and appropriate to me. Increases memory usage for concurrency, but limits cpu time spent on gc as it's pre-allocated to a larger size. Maybe let's compromize and set at 2/3 kb and let it grow. 
