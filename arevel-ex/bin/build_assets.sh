pushd assets
npm install
./node_modules/webpack/bin/webpack.js --mode production
popd
mix phx.digest
