# Setup
Install rust
https://www.rust-lang.org/

Install cargo - rust package manager
https://doc.rust-lang.org/cargo/getting-started/installation.html

Run the site
```
cd site
cargo run
```

You'll need to symlink the static files to the web directory for the server to serve it properly
```
# Build the static files
cd site/static
npm install
npm run deploy

sudo mkdir -p /var/www/arevelcom
sudo chown arevelapp /var/www/arevelcom
cd /var/www/arevelcom
# Replace /app/arevel-release with your local path to arevel
ln -s /app/arevel-release/static/ static
ln -s /app/arevel-release/templates/ templates
```

# AVS
AVS is the Arevel standard library used in both the interpreted and compiled WASM mode. 
Once you make changes to the library, you'll need to re-compile a header.wat and footer.wat file. 
These are the compiled versions of the standard library. Install wasm-pack from https://rustwasm.github.io/wasm-pack/ 
then run `avs/build.sh` to generate these files.




# Setup
Install rust
https://www.rust-lang.org/

Install cargo - rust package manager
https://doc.rust-lang.org/cargo/getting-started/installation.html

Run the project
```
cargo run
```


cd /var/www/appassembly
ln -s ~/code/appassembly/static/dist/static static
ln -s ~/code/appassembly/templates templates

Setup db

```
sudo apt install postgresql postgresql-contrib


apt-get install libpq-dev

cargo install diesel_cli --no-default-features --features postgres


createuser --interactive --pwprompt
aasm

grant all on aasmdb to aasm

psql --user aasm --password -d aasmdb --host localhost

```

Diesel ORM
```
diesel setup
diesel migration generate create_routes
diesel migration run
```
