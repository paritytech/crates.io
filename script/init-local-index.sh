#!/bin/bash

set -e

this_file="$(realpath -s "${BASH_SOURCE[0]}")"
this_dir="${this_file%/*}"
project_root="${this_dir%/*}"

cd "$project_root"

if [ -d tmp/index-bare ]; then
    echo tmp/index-bare already exists, exiting
    exit 0
fi

mkdir -p tmp
rm -rf tmp/index-bare tmp/index-tmp

echo "Initializing repository in tmp/index-bare..."
git init -q --bare --initial-branch=master tmp/index-bare

echo "Creating temporary clone in tmp/index-tmp..."
git clone --depth 1 https://github.com/rust-lang/crates.io-index tmp/index-tmp
rm -rf tmp/index-tmp/.git
git init -q --initial-branch=master tmp/index-tmp
cd tmp/index-tmp
cat > config.json <<-EOF
{
  "dl": "http://localhost:8888/api/v1/crates",
  "api": "http://localhost:8888/"
}
EOF
git add .
git commit -qm 'Initial commit'
git remote add origin file://"$project_root"/tmp/index-bare
git push -q origin master -u > /dev/null

cd "$project_root"

# Remove the temporary checkout
rm -rf tmp/index-tmp

# Allow the index to be exported via HTTP during local development
touch tmp/index-bare/git-daemon-export-ok

cat - <<-EOF
Your local git index is ready to go!

Please refer to https://github.com/rust-lang/crates.io/blob/master/docs/CONTRIBUTING.md for more info!
EOF
