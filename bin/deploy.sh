# TODO: npm
# TODO copy statics dir


AREVEL_BASE=~/code/arevel/
RELEASE_DIR=~/code/arevel/target/arevel-release

cd $AREVEL_BASE
mkdir target/arevel-release

# Build artifact in release mode
cd $AREVEL_BASE/site/static
npm run deploy

cp -r dist/static $RELEASE_DIR/static

cd $AREVEL_BASE/site/
cargo build --release
cp $AREVEL_BASE/target/release/site $RELEASE_DIR/arevel


cd $AREVEL_BASE/avs
./build.sh
cp header.wat $RELEASE_DIR
cp footer.wat $RELEASE_DIR


cd $RELEASE_DIR/..
tar -zcvf arevel-release.tar.gz arevel-release


# Deploy code to google storage
#gsutil cp _build/prod/rel/arevel/bin/arevel.run \
#    gs://arevel-209217-releases/arevel-release
