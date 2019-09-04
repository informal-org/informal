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